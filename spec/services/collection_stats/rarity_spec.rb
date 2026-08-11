require 'rails_helper'

RSpec.describe CollectionStats::Rarity, type: :service do
  subject(:rows) { described_class.call(collection_ids: [collection.id]) }

  let(:collection) { create(:collection) }

  def add(rarity, quantity: 1, price: 10)
    card = create(:magic_card, rarity: rarity, normal_price: price)
    create(:collection_magic_card, collection: collection, magic_card: card, quantity: quantity)
  end

  describe 'ordering' do
    it 'runs mythic down to common regardless of insertion order' do
      %w[common mythic uncommon rare].each { |rarity| add(rarity) }

      expect(rows.map { |row| row[:rarity] }).to eq(%w[mythic rare uncommon common])
    end

    # reuse, so the dashboard and the collection page's rarity grouping cannot disagree
    it 'takes its order from the collection page grouping' do
      expect(described_class::ORDER).to be(Collections::GroupCards::RARITY_ORDER)
    end

    it 'sorts rarities the app has no opinion about to the end rather than dropping them' do
      add('mythic')
      add('bonus')

      expect(rows.map { |row| row[:label] }).to eq(%w[Mythic Bonus])
    end

    it 'labels a missing rarity rather than blanking the row' do
      add(nil)

      expect(rows.map { |row| row[:label] }).to eq(['Unknown'])
    end
  end

  describe 'figures' do
    it 'sums copies and value per rarity' do
      add('rare', quantity: 3, price: 10)
      add('rare', quantity: 2, price: 5)
      add('common', quantity: 1, price: 1)

      rare = rows.find { |row| row[:rarity] == 'rare' }

      expect(rare[:copies]).to eq(5)
      expect(rare[:value]).to eq(40)
      expect(rare[:printings]).to eq(2)
    end

    # copies count all four finishes; value counts the two real ones - 1 + 2, not 1 + 2 + 1 + 2
    it 'counts every finish but values real copies only' do
      card = create(:magic_card, rarity: 'mythic', normal_price: 1, foil_price: 2)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 1, foil_quantity: 1,
                                     proxy_quantity: 1, proxy_foil_quantity: 1)

      expect(rows.first[:copies]).to eq(4)
      expect(rows.first[:value]).to eq(3)
    end

    it 'gives each rarity its share of total value' do
      add('mythic', quantity: 1, price: 75)
      add('common', quantity: 1, price: 25)

      expect(rows.map { |row| row[:share] }).to eq([75.0, 25.0])
    end

    it 'excludes staged and wishlist rows' do
      card = create(:magic_card, rarity: 'rare', normal_price: 5)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 4, staged: true)

      expect(rows).to be_empty
    end
  end

  it 'returns nothing and runs no queries when there are no collections' do
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
    end
    result = described_class.call(collection_ids: [])
    ActiveSupport::Notifications.unsubscribe(subscriber)

    expect(result).to eq([])
    expect(queries).to be_empty
  end
end
