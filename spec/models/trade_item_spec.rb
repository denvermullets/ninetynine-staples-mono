require 'rails_helper'

RSpec.describe TradeItem, type: :model do
  describe 'validations' do
    it 'refuses a side that is neither end of the trade' do
      item = build(:trade_item, side: 'spectator')
      expect(item).not_to be_valid
      expect(item.errors[:side]).to be_present
    end

    it 'refuses an item offering no copies at all' do
      item = build(:trade_item, quantity: 0, foil_quantity: 0)
      expect(item).not_to be_valid
    end

    it 'accepts a foil-only item' do
      expect(build(:trade_item, quantity: 0, foil_quantity: 1)).to be_valid
    end

    it 'survives its collection row being deleted' do
      card = create(:collection_magic_card)
      item = create(:trade_item, collection_magic_card: card, magic_card: card.magic_card)
      card.destroy
      expect(item.reload.collection_magic_card).to be_nil
    end
  end

  describe 'values' do
    let(:item) do
      build(:trade_item, quantity: 2, foil_quantity: 1, unit_price_snapshot: 5, unit_foil_price_snapshot: 10,
                         unit_buylist_snapshot: 2, unit_buylist_foil_snapshot: 4)
    end

    it 'prices each finish at its own snapshot' do
      expect(item.retail_value).to eq(20)
      expect(item.buylist_value).to eq(8)
    end
  end
end
