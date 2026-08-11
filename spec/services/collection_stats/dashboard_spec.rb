require 'rails_helper'

RSpec.describe CollectionStats::Dashboard, type: :service do
  let(:user) { create(:user, username: 'owner') }
  let!(:public_collection) { create(:collection, user: user, is_public: true) }
  let!(:private_collection) { create(:collection, user: user, is_public: false) }

  def queries_for(...)
    captured = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      captured << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
    end
    described_class.call(...)
    captured
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  describe 'what it returns' do
    # the shell is deliberately not "everything": it is the one panel show.html.erb cannot defer,
    # because it decides between the empty state and the dashboard
    it 'builds only the shell panel when no section is asked for' do
      result = described_class.call(username: user.username, viewer: user)

      expect(result).to have_key(:overview)
      expect(result.keys).not_to include(:rarity, :price_tiers, :card_types, :colors, :mana_curve,
                                         :sets, :top_cards, :price_movers, :roles)
    end

    it 'builds exactly the panels belonging to the section asked for' do
      described_class::SECTIONS.each do |section, config|
        result = described_class.call(username: user.username, viewer: user, section: section)

        expect(result.slice(*described_class::PANELS.keys).keys).to eq(config[:panels])
      end
    end

    # between them the sections have to account for every panel, or one is unreachable
    it 'covers every panel across the shell and the sections' do
      covered = described_class::SHELL + described_class::SECTIONS.values.flat_map { |s| s[:panels] }

      expect(covered.sort).to eq(described_class::PANELS.keys.sort)
      expect(covered.tally.values).to all(eq(1))
    end

    it 'opens on a section that exists' do
      expect(described_class.section?(described_class::DEFAULT_SECTION)).to be(true)
    end

    it 'refuses a section it does not know' do
      expect(described_class.section?('made_up')).to be(false)
      expect { described_class.call(username: user.username, viewer: user, section: 'made_up') }
        .to raise_error(KeyError)
    end

    # the panels are skipped entirely rather than run against an empty id list - a missing scope
    # has nothing to report on
    it 'returns the bare scope and no panels when the collection is not the viewer\'s to see' do
      result = described_class.call(username: user.username, viewer: nil,
                                    collection_id: private_collection.id)

      expect(result[:missing]).to be(true)
      expect(result).not_to have_key(:overview)
    end

    it 'leaves private holdings out of what a visitor is shown' do
      card = create(:magic_card, normal_price: 1234.56)
      create(:collection_magic_card, collection: private_collection, magic_card: card, quantity: 1)

      result = described_class.call(username: user.username, viewer: nil)

      expect(result[:overview][:total_value]).to eq(0)
    end
  end

  # this is the guard the panels were written for: every one of them aggregates in SQL against the
  # `owned` CTE, so the number of round trips is a function of how many panels there are and
  # nothing else. A panel that loaded records and summed them in Ruby would show up here first.
  describe 'query budget' do
    before { 3.times { create(:collection_magic_card, collection: public_collection, quantity: 1) } }

    it 'never falls back to per-card lookups' do
      queries = described_class::SECTIONS.keys.flat_map do |section|
        queries_for(username: user.username, viewer: user, section: section)
      end

      expect(queries.grep(/FROM "magic_cards" WHERE "magic_cards"\."id" = /)).to be_empty
    end

    it 'stays inside a fixed round-trip budget regardless of collection size' do
      3.times { create(:collection_magic_card, collection: private_collection, quantity: 2) }

      queries = queries_for(username: user.username, viewer: user)

      expect(queries.grep(/FROM "collection_magic_cards"/).size).to eq(1)
    end

    # the whole point of the split: no single request pays for all ten panels
    it 'keeps every section down to a handful of scans' do
      described_class::SECTIONS.each_key do |section|
        queries = queries_for(username: user.username, viewer: user, section: section)

        expect(queries.grep(/FROM "collection_magic_cards"/).size).to be <= 4
      end
    end
  end
end
