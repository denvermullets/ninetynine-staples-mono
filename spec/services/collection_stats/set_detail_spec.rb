require 'rails_helper'

RSpec.describe CollectionStats::SetDetail, type: :service do
  subject(:result) { described_class.call(collection_ids: [collection.id], boxset: set) }

  let(:collection) { create(:collection) }
  let(:set) { create(:boxset, name: 'Alpha', base_set_size: 2, total_set_size: 4) }

  # the factory leaves card_number nil, and the base run is read off it, so every card here says
  # where in the set it sits
  def card(number, **attributes)
    create(:magic_card, boxset: set, card_number: number.to_s, **attributes)
  end

  def own(magic_card, **attributes)
    create(:collection_magic_card, { collection: collection, magic_card: magic_card,
                                     quantity: 1 }.merge(attributes))
  end

  def track_queries
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
    end
    yield
    ActiveSupport::Notifications.unsubscribe(subscriber)
    queries
  end

  describe 'the headline' do
    # the whole point of the page is that clicking a row on the completion panel does not change the
    # number you clicked, so this has to agree with SetCompletion on the same data
    it 'measures the numbered run and matches what the completion panel reports' do
      own(card(1))
      card(2)
      own(card(3))
      card(4)

      expect(result).to include(owned: 1, total: 2, missing: 1, share: 50.0, basis: :base,
                                variant_owned: 2, variant_total: 4, variant_share: 50.0)
      expect(CollectionStats::SetCompletion.call(collection_ids: [collection.id])[:sets].first)
        .to include(owned: result[:owned], total: result[:total], share: result[:share])
    end

    it 'measures a set with no meaningful run across every printing' do
      set.update!(base_set_size: 1)
      own(card(1))
      own(card(2))
      card(3)
      card(4)

      expect(result).to include(basis: :all, owned: 2, total: 4, share: 50.0)
    end

    it 'carries the set identity the header labels with' do
      set.update!(code: 'LEA', keyrune_code: 'LEA', release_date: '1993-08-05')
      own(card(1))

      expect(result).to include(label: 'Alpha', code: 'LEA', year: 1993,
                                icon: 'no-tailwind ss ss-lea ss-fw')
    end

    it 'reports a set nothing is owned from rather than refusing to open' do
      card(1)
      card(2)

      expect(result).to include(owned: 0, total: 2, share: 0.0, missing: 2)
    end
  end

  describe 'what your copies are worth' do
    it 'prices every copy of every printing, variants included' do
      own(card(1), quantity: 2, foil_quantity: 1)
      own(card(3), quantity: 1)

      expect(result[:value]).to eq(25) # (2 x 5) + (1 x 10) + (1 x 5)
    end

    # a proxy is cardstock. Pricing it at what the real card sells for inflates the figure by
    # whatever the pile would cost to buy for real
    it 'leaves proxies out of the value' do
      own(card(1), quantity: 1, proxy_quantity: 4, proxy_foil_quantity: 2)

      expect(result[:value]).to eq(5)
    end
  end

  describe 'what finishing it would cost' do
    it 'prices the cards missing from the run and ignores the variants' do
      own(card(1))
      card(2, normal_price: 12)
      card(3, normal_price: 99)
      card(4, normal_price: 99)

      expect(result[:cost_to_complete]).to eq(12)
    end

    it 'prices every printing when the set has no run to measure against' do
      set.update!(base_set_size: 1)
      own(card(1))
      card(2, normal_price: 3)
      card(3, normal_price: 4)

      expect(result[:cost_to_complete]).to eq(7)
    end

    # a foil-only printing has a normal_price of 0 and still costs money to acquire
    it 'falls back to the foil price on a printing with no non-foil' do
      own(card(1))
      card(2, normal_price: 0, foil_price: 8)

      expect(result[:cost_to_complete]).to eq(8)
    end

    it 'counts a printing held only as a proxy as one you still have to buy' do
      own(card(1))
      own(card(2, normal_price: 12), quantity: 0, proxy_quantity: 3)

      expect(result).to include(owned: 1, missing: 1)
      expect(result[:cost_to_complete]).to eq(12)
    end
  end

  # A separate metric, not a component of completion. Somebody chasing the set in foil is answering
  # a different question from somebody chasing the set, and folding the two together would tell a
  # collector with a finished non-foil run that they are at 40%.
  describe 'foils' do
    def with_finish(magic_card, name)
      MagicCardFinish.create!(magic_card: magic_card, finish: Finish.find_or_create_by!(name: name))
      magic_card
    end

    it 'counts the foils you hold against the printings that have one' do
      own(with_finish(card(1), 'foil'), quantity: 0, foil_quantity: 1)
      with_finish(card(2), 'foil')

      expect(result[:foils]).to include(owned: 1, total: 2, missing: 1, share: 50.0)
    end

    # a card never sold in foil is not a foil you are missing, so it stays out of the denominator
    it 'leaves a printing with no foil out of both sides' do
      own(with_finish(card(1), 'foil'), quantity: 0, foil_quantity: 1)
      with_finish(card(2), 'nonfoil')

      expect(result[:foils]).to include(owned: 1, total: 1, share: 100.0)
    end

    it 'does not count a non-foil copy as having the foil' do
      own(with_finish(card(1), 'foil'), quantity: 4, foil_quantity: 0)

      expect(result[:foils]).to include(owned: 0, total: 1)
    end

    it 'does not count a proxied foil as having the foil' do
      own(with_finish(card(1), 'foil'), quantity: 1, foil_quantity: 0, proxy_foil_quantity: 3)

      expect(result[:foils]).to include(owned: 0, missing: 1)
    end

    it 'prices the foils still outstanding' do
      own(with_finish(card(1), 'foil'), quantity: 0, foil_quantity: 1)
      with_finish(card(2, foil_price: 14), 'foil')

      expect(result[:foils][:cost]).to eq(14)
    end

    # the whole reason it is a separate tile
    it 'leaves the completion numbers exactly where they were' do
      own(with_finish(card(1), 'foil'), quantity: 1, foil_quantity: 0)
      own(with_finish(card(2), 'foil'), quantity: 1, foil_quantity: 0)

      expect(result).to include(owned: 2, total: 2, share: 100.0, missing: 0)
      expect(result[:cost_to_complete]).to eq(0)
      expect(result[:foils]).to include(owned: 0, share: 0.0)
    end
  end

  describe 'what is left, by rarity' do
    it 'counts the missing cards in the run and ranks the expensive end first' do
      set.update!(base_set_size: 4, total_set_size: 5)
      own(card(1, rarity: 'common'))
      card(2, rarity: 'common')
      card(3, rarity: 'mythic')
      card(4, rarity: 'uncommon')
      card(5, rarity: 'mythic')

      expect(result[:missing_by_rarity].to_a).to eq([['mythic', 1], ['uncommon', 1], ['common', 1]])
    end

    it 'leaves out a rarity there is nothing missing from' do
      own(card(1, rarity: 'rare'))
      card(2, rarity: 'common')

      expect(result[:missing_by_rarity]).to eq({ 'common' => 1 })
    end
  end

  describe 'what is not a card you can collect' do
    it 'ignores tokens and the back face of a double-faced card' do
      own(card(1))
      card(2)
      own(card(3, is_token: true))
      own(card(4, card_side: 'b'))

      expect(result).to include(owned: 1, total: 2, variant_owned: 1, variant_total: 2)
    end

    it 'ignores staged and wishlist rows, same as the rest of the dashboard' do
      own(card(1), staged: true)
      own(card(2), needed: true)

      expect(result).to include(owned: 0, total: 2)
    end
  end

  it 'asks two questions: the counters and the money together, the rarity breakdown apart' do
    own(card(1))
    card(2)

    queries = track_queries { result }

    expect(queries.size).to eq(2)
  end
end
