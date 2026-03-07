require 'rails_helper'

RSpec.describe CardScanner::Search, type: :service do
  let(:user) { create(:user) }
  let(:boxset) { create(:boxset, code: 'TST') }
  let!(:card) {
    create(:magic_card, name: 'Lightning Bolt', card_number: '141', boxset: boxset, card_side: nil, is_token: false)
  }

  context 'searching by set code and card number' do
    it 'finds the card' do
      result = described_class.call(set_code: 'TST', card_number: '141', user: user)
      expect(result).not_to be_empty
      expect(result.first[:card].name).to eq('Lightning Bolt')
    end
  end

  context 'searching by query name' do
    it 'finds cards matching the name' do
      result = described_class.call(query: 'Lightning Bolt', user: user)
      expect(result).not_to be_empty
      expect(result.first[:card].name).to eq('Lightning Bolt')
    end
  end

  context 'with no search criteria' do
    it 'returns empty array' do
      result = described_class.call(user: user)
      expect(result).to eq([])
    end
  end

  context 'with no match' do
    it 'returns empty array' do
      result = described_class.call(set_code: 'ZZZ', card_number: '999', user: user)
      expect(result).to eq([])
    end
  end

  context 'enriches with ownership data' do
    let(:collection) { create(:collection, user: user, collection_type: 'binder') }

    before do
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 2, foil_quantity: 0)
    end

    it 'includes owned quantities' do
      result = described_class.call(set_code: 'TST', card_number: '141', user: user)
      expect(result.first[:owned][:quantity]).to eq(2)
    end
  end
end
