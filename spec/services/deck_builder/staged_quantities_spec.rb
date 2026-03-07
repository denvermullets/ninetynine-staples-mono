require 'rails_helper'

RSpec.describe DeckBuilder::StagedQuantities, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:source_collection) { create(:collection, user: user) }
  let(:magic_card) { create(:magic_card) }

  let!(:staged_card) do
    create(:collection_magic_card,
           collection: deck,
           magic_card: magic_card,
           source_collection_id: source_collection.id,
           staged: true,
           staged_quantity: 2,
           staged_foil_quantity: 1,
           staged_proxy_quantity: 1,
           staged_proxy_foil_quantity: 0,
           quantity: 0,
           foil_quantity: 0)
  end

  describe '.call' do
    subject do
      described_class.call(
        source_collection_id: source_collection.id,
        magic_card_id: magic_card.id
      )
    end

    it 'returns staged quantities for all types' do
      expect(subject).to eq(regular: 2, foil: 1, proxy: 1, proxy_foil: 0)
    end

    context 'with exclude_card_id' do
      subject do
        described_class.call(
          source_collection_id: source_collection.id,
          magic_card_id: magic_card.id,
          exclude_card_id: staged_card.id
        )
      end

      it 'excludes the specified card' do
        expect(subject).to eq(regular: 0, foil: 0, proxy: 0, proxy_foil: 0)
      end
    end
  end

  describe '.calculate_available' do
    let!(:source_card) do
      create(:collection_magic_card,
             collection: source_collection,
             magic_card: magic_card,
             quantity: 4,
             foil_quantity: 3,
             proxy_quantity: 2,
             proxy_foil_quantity: 1,
             staged: false,
             needed: false)
    end

    it 'returns available quantities after subtracting staged' do
      result = described_class.calculate_available(source: source_card)
      expect(result).to eq(regular: 2, foil: 2, proxy: 1, proxy_foil: 1)
    end
  end

  describe '.total_staged' do
    it 'returns the total of all staged quantities' do
      result = described_class.total_staged(
        source_collection_id: source_collection.id,
        magic_card_id: magic_card.id
      )
      expect(result).to eq(4) # 2 + 1 + 1 + 0
    end
  end
end
