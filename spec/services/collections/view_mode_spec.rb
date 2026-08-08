require 'rails_helper'

RSpec.describe Collections::ViewMode, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let!(:bolt) { create(:magic_card, name: 'Lightning Bolt') }

  before { create(:collection_magic_card, collection: collection, magic_card: bolt, quantity: 2) }

  let(:filtered_cards) do
    Search::Collection.call(
      cards: MagicCard.joins(collection_magic_cards: :collection).where(collections: { user_id: user.id }),
      search_term: '', sort_by: :price
    )
  end

  def view(params: {}, total_count: 1, cards: filtered_cards)
    described_class.new(filtered_cards: cards, user: user, params: params, total_count: total_count)
  end

  context 'when the count is zero' do
    it 'returns the empty result' do
      result = view(total_count: 0).call

      expect(result[:magic_cards]).to eq([])
      expect(result[:pagy]).to be_nil
      expect(result[:aggregated_quantities]).to be_nil
      expect(result[:grouped_cards]).to be_nil
    end

    # the whole point of taking the count as an argument: the caller already paid for one query
    # and this used to spend a second one on exists? against the same grouped relation
    it 'does not query the database' do
      queries = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
      end

      view(total_count: 0).call

      expect(queries).to be_empty
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end

  context 'when the count is positive' do
    it 'returns the relation unpaginated for the caller to paginate' do
      result = view(total_count: 1).call

      expect(result[:magic_cards]).to eq(filtered_cards)
      expect(result[:view_mode]).to eq('table')
      expect(result[:grouping]).to eq('none')
    end

    it 'reads the view mode and grouping from params' do
      result = view(params: { view_mode: 'table', grouping: 'rarity', code: 'TST' }).call

      expect(result[:view_mode]).to eq('table')
      expect(result[:grouping]).to eq('rarity')
      expect(result[:grouping_allowed]).to be(true)
    end
  end

  describe '#skip_pagination?' do
    it 'is true for grouped visual mode within a boxset' do
      expect(view(params: { view_mode: 'visual', grouping: 'rarity', code: 'TST' })).to be_skip_pagination
    end

    it 'is false without a grouping' do
      expect(view(params: { view_mode: 'visual', grouping: 'none', code: 'TST' })).not_to be_skip_pagination
    end

    it 'is false in table mode' do
      expect(view(params: { view_mode: 'table', grouping: 'rarity', code: 'TST' })).not_to be_skip_pagination
    end

    it 'is false outside a boxset' do
      expect(view(params: { view_mode: 'visual', grouping: 'rarity' })).not_to be_skip_pagination
    end
  end
end
