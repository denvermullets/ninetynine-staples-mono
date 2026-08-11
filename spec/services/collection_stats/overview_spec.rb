require 'rails_helper'

RSpec.describe CollectionStats::Overview, type: :service do
  subject(:overview) { described_class.call(collection_ids: [collection.id]) }

  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }

  def queries_while
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
    end

    yield

    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  describe 'pricing each quantity bucket' do
    it 'prices real copies off normal_price and foil copies off foil_price' do
      card = create(:magic_card, normal_price: 3, foil_price: 12)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 2, foil_quantity: 1)

      expect(overview[:real_value]).to eq(18)
      expect(overview[:real_cards]).to eq(3)
    end

    it 'prices proxies off the same columns when both prices exist' do
      card = create(:magic_card, normal_price: 3, foil_price: 12)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 0, proxy_quantity: 2, proxy_foil_quantity: 1)

      expect(overview[:proxy_value]).to eq(18)
      expect(overview[:proxy_cards]).to eq(3)
    end

    # mirrors MagicCard#proxy_normal_price - a proxy of a foil-only printing is not worthless
    it 'falls back to the other finish when a proxy has no price for its own' do
      card = create(:magic_card, normal_price: 0, foil_price: 20)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 0, proxy_quantity: 1)

      expect(overview[:proxy_value]).to eq(20)
    end

    it 'treats nil prices as zero rather than blowing up' do
      card = create(:magic_card, normal_price: nil, foil_price: nil)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 3)

      expect(overview[:total_value]).to eq(0)
      expect(overview[:total_cards]).to eq(3)
    end
  end

  describe 'the bulk split' do
    # the whole reason this is priced per copy: one printing, two prices, one on each side
    it 'splits a printing whose finishes fall on either side of the threshold' do
      card = create(:magic_card, normal_price: 0.4, foil_price: 30)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 5, foil_quantity: 2)

      expect(overview[:bulk_cards]).to eq(5)
      expect(overview[:bulk_value]).to eq(2)
      expect(overview[:priced_cards]).to eq(2)
      expect(overview[:priced_value]).to eq(60)
    end

    it 'counts a copy priced exactly at the threshold as priced, not bulk' do
      card = create(:magic_card, normal_price: 1, foil_price: 0.99)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 1, foil_quantity: 1)

      expect(overview[:priced_cards]).to eq(1)
      expect(overview[:bulk_cards]).to eq(1)
    end

    # proxies are bucketed on the same fallback price they are valued at, so a proxy of a foil-only
    # $20 card is not filed as chaff
    it 'buckets proxies on the price they fall back to' do
      card = create(:magic_card, normal_price: 0, foil_price: 20)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 0, proxy_quantity: 1)

      expect(overview[:priced_cards]).to eq(1)
      expect(overview[:bulk_cards]).to eq(0)
    end

    it 'treats an unpriced card as bulk' do
      card = create(:magic_card, normal_price: nil, foil_price: nil)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 3)

      expect(overview[:bulk_cards]).to eq(3)
      expect(overview[:priced_cards]).to eq(0)
    end

    it 'reports the priced side as a share of every copy' do
      cheap = create(:magic_card, normal_price: 0.1)
      dear = create(:magic_card, normal_price: 40)
      create(:collection_magic_card, collection: collection, magic_card: cheap, quantity: 3)
      create(:collection_magic_card, collection: collection, magic_card: dear, quantity: 1)

      expect(overview[:priced_share]).to eq(25.0)
    end

    it 'has both sides add up to the totals beside them' do
      [0.25, 0.99, 1, 7.5, 250].each_with_index do |price, index|
        card = create(:magic_card, normal_price: price, foil_price: price * 2)
        create(:collection_magic_card, collection: collection, magic_card: card,
                                       quantity: index + 1, foil_quantity: 1, proxy_quantity: 2)
      end

      expect(overview[:bulk_cards] + overview[:priced_cards]).to eq(overview[:total_cards])
      expect(overview[:bulk_value] + overview[:priced_value]).to eq(overview[:total_value])
    end

    # the number would be worse than useless if it disagreed with the panel it summarises
    it 'agrees with the bottom tier of the Price Buckets panel' do
      [0.25, 0.99, 1, 7.5, 250].each_with_index do |price, index|
        card = create(:magic_card, normal_price: price, foil_price: price * 2)
        create(:collection_magic_card, collection: collection, magic_card: card,
                                       quantity: index + 1, foil_quantity: 1, proxy_quantity: 2)
      end
      under = CollectionStats::PriceTiers.call(collection_ids: [collection.id])[:tiers].first

      expect(under[:label]).to eq(described_class::BULK_TIER[:label])
      expect(overview[:bulk_cards]).to eq(under[:copies])
      expect(overview[:bulk_value]).to eq(under[:value])
    end

    it 'reports zeroes rather than dividing by nothing on an empty scope' do
      result = described_class.call(collection_ids: [])

      expect(result[:bulk_cards]).to eq(0)
      expect(result[:priced_cards]).to eq(0)
      expect(result[:priced_share]).to eq(0.0)
    end
  end

  describe 'row scope' do
    let(:card) { create(:magic_card, normal_price: 5) }

    it 'ignores staged deck-builder rows' do
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 4, staged: true)

      expect(overview[:total_cards]).to eq(0)
    end

    it 'ignores wishlist rows' do
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 4, needed: true)

      expect(overview[:total_cards]).to eq(0)
    end
  end

  describe 'a printing held in more than one collection' do
    it 'counts one unique printing with the copies summed' do
      other = create(:collection, user: user)
      card = create(:magic_card, normal_price: 5)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 2)
      create(:collection_magic_card, collection: other, magic_card: card, quantity: 3)

      result = described_class.call(collection_ids: [collection.id, other.id])

      expect(result[:unique_printings]).to eq(1)
      expect(result[:total_cards]).to eq(5)
      expect(result[:real_value]).to eq(25)
    end
  end

  describe 'derived figures' do
    it 'averages value over real copies only, so proxies do not dilute it' do
      card = create(:magic_card, normal_price: 10, foil_price: 10)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 2, proxy_quantity: 8)

      expect(overview[:avg_card_value]).to eq(10)
    end

    it 'splits foil from non-foil across real and proxy copies alike' do
      card = create(:magic_card, normal_price: 1, foil_price: 1)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 1, foil_quantity: 2,
                                     proxy_quantity: 3, proxy_foil_quantity: 4)

      expect(overview[:nonfoil_cards]).to eq(4)
      expect(overview[:foil_cards]).to eq(6)
      expect(overview[:foil_share]).to eq(60.0)
    end

    it 'reports buylist value as a share of market value' do
      card = create(:magic_card, normal_price: 10, ck_buylist_normal_price: 4)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 5)

      expect(overview[:buylist_value]).to eq(20)
      expect(overview[:buylist_ratio]).to eq(40.0)
    end

    # price_change_weekly_* is a percentage, so the dollar move has to be recovered from it
    it 'converts the weekly percentage change into a dollar figure' do
      card = create(:magic_card, normal_price: 110, price_change_weekly_normal: 10)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 2)

      # was 100, now 110, so +10 a copy
      expect(overview[:weekly_delta]).to eq(20)
    end

    it 'contributes nothing for a card whose price fell to zero' do
      card = create(:magic_card, normal_price: 0, foil_price: 0, price_change_weekly_normal: -100)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 2)

      expect(overview[:weekly_delta]).to eq(0)
    end

    it 'counts distinct sets' do
      boxset = create(:boxset)
      create(:collection_magic_card, collection: collection,
                                     magic_card: create(:magic_card, boxset: boxset))
      create(:collection_magic_card, collection: collection,
                                     magic_card: create(:magic_card, boxset: boxset))
      create(:collection_magic_card, collection: collection, magic_card: create(:magic_card))

      expect(overview[:unique_sets]).to eq(2)
    end
  end

  describe 'agreement with the stored rollups' do
    it 'matches total_estimated_value once the rollup has been recomputed' do
      card = create(:magic_card, normal_price: 7, foil_price: 13)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 3, foil_quantity: 2, proxy_quantity: 1)
      Collections::UpdateTotals.call(collection: collection.reload)

      expect(overview[:total_value]).to eq(collection.reload.total_estimated_value)
      expect(overview[:total_cards]).to eq(collection.total_cards)
    end
  end

  describe 'query budget' do
    it 'reads everything in a single query' do
      create(:collection_magic_card, collection: collection, quantity: 1)

      queries = queries_while { described_class.call(collection_ids: [collection.id]) }

      expect(queries.size).to eq(1)
    end

    it 'runs no queries at all when there are no collections' do
      queries = queries_while { described_class.call(collection_ids: []) }

      expect(queries).to be_empty
    end

    it 'returns zeroed figures when there are no collections' do
      result = described_class.call(collection_ids: [])

      expect(result[:total_value]).to eq(0)
      expect(result[:total_cards]).to eq(0)
      expect(result[:buylist_ratio]).to eq(0.0)
    end
  end
end
