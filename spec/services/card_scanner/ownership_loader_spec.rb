require 'rails_helper'

RSpec.describe CardScanner::OwnershipLoader, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user, collection_type: 'binder') }
  let(:magic_card) { create(:magic_card) }

  let!(:cmc) do
    create(:collection_magic_card,
           collection: collection,
           magic_card: magic_card,
           quantity: 3,
           foil_quantity: 1,
           proxy_quantity: 2,
           proxy_foil_quantity: 0)
  end

  context 'when user owns cards' do
    it 'returns ownership hash keyed by magic_card_id' do
      result = described_class.call(card_ids: [magic_card.id], user: user)
      expect(result[magic_card.id][:quantity]).to eq(3)
      expect(result[magic_card.id][:foil_quantity]).to eq(1)
      expect(result[magic_card.id][:proxy_quantity]).to eq(2)
    end
  end

  context 'when user has no cards' do
    it 'returns empty hash for unknown card ids' do
      result = described_class.call(card_ids: [-1], user: user)
      expect(result).to be_empty
    end
  end

  context 'when user is nil' do
    it 'returns empty hash' do
      result = described_class.call(card_ids: [magic_card.id], user: nil)
      expect(result).to eq({})
    end
  end

  context 'excludes deck collections' do
    let(:deck) { create(:collection, user: user, collection_type: 'deck') }

    before do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             quantity: 5,
             foil_quantity: 0)
    end

    it 'does not include cards from decks' do
      result = described_class.call(card_ids: [magic_card.id], user: user)
      expect(result[magic_card.id][:quantity]).to eq(3)
    end
  end
end
