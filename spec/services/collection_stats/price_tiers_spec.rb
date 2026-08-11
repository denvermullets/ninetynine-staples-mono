require 'rails_helper'

RSpec.describe CollectionStats::PriceTiers, type: :service do
  subject(:result) { described_class.call(collection_ids: [collection.id]) }

  let(:collection) { create(:collection) }

  def tier(label)
    result[:tiers].find { |row| row[:label] == label }
  end

  describe 'banding' do
    it 'puts a card just under a boundary in the lower band' do
      card = create(:magic_card, normal_price: 0.99)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1)

      expect(tier('<$1')[:copies]).to eq(1)
      expect(tier('$1-5')[:copies]).to eq(0)
    end

    it 'puts a card exactly on a boundary in the upper band' do
      card = create(:magic_card, normal_price: 1)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1)

      expect(tier('<$1')[:copies]).to eq(0)
      expect(tier('$1-5')[:copies]).to eq(1)
    end

    it 'lands anything expensive in the top band' do
      card = create(:magic_card, normal_price: 250)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 2)

      expect(tier('$100+')[:copies]).to eq(2)
      expect(tier('$100+')[:value]).to eq(500)
    end
  end

  # the entire reason this service uses CROSS JOIN LATERAL rather than a grouped aggregate
  describe 'a single row holding copies at different unit prices' do
    it 'bands each finish separately' do
      card = create(:magic_card, normal_price: 0.50, foil_price: 30)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 1, foil_quantity: 1)

      expect(tier('<$1')[:copies]).to eq(1)
      expect(tier('<$1')[:value]).to eq(0.50)
      expect(tier('$20-50')[:copies]).to eq(1)
      expect(tier('$20-50')[:value]).to eq(30)
    end

    it 'bands a proxy on its fallback price, not zero' do
      card = create(:magic_card, normal_price: 0, foil_price: 40)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 0, proxy_quantity: 1)

      expect(tier('$20-50')[:copies]).to eq(1)
      expect(tier('<$1')[:copies]).to eq(0)
    end
  end

  describe 'empty buckets' do
    it 'ignores finishes with no copies' do
      card = create(:magic_card, normal_price: 5, foil_price: 500)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 1, foil_quantity: 0)

      expect(tier('$100+')[:copies]).to eq(0)
      expect(tier('$5-20')[:copies]).to eq(1)
    end

    it 'still returns every band when the collection is empty' do
      expect(result[:tiers].map { |row| row[:label] }).to eq(described_class::TIERS.map { |t| t[:label] })
      expect(result[:tiers].sum { |row| row[:copies] }).to eq(0)
    end
  end

  describe 'totals' do
    it 'reports the share of value sitting in the top band' do
      cheap = create(:magic_card, normal_price: 10)
      pricey = create(:magic_card, normal_price: 300)
      create(:collection_magic_card, collection: collection, magic_card: cheap, quantity: 10)
      create(:collection_magic_card, collection: collection, magic_card: pricey, quantity: 1)

      expect(result[:top_tier_share]).to eq(75.0)
    end

    it 'excludes staged and wishlist rows' do
      card = create(:magic_card, normal_price: 10)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 5, staged: true)

      expect(result[:tiers].sum { |row| row[:copies] }).to eq(0)
    end
  end

  it 'runs no queries when there are no collections' do
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
    end
    described_class.call(collection_ids: [])
    ActiveSupport::Notifications.unsubscribe(subscriber)

    expect(queries).to be_empty
  end
end
