require 'rails_helper'

RSpec.describe DeckBuilder::CalculateEditAvailability, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:source_collection) { create(:collection, user: user) }
  let(:magic_card) { create(:magic_card) }

  context 'when card has a source collection' do
    let!(:source_card) do
      create(:collection_magic_card,
             collection: source_collection,
             magic_card: magic_card,
             quantity: 4,
             foil_quantity: 2,
             proxy_quantity: 1,
             proxy_foil_quantity: 1,
             staged: false,
             needed: false)
    end

    let!(:staged_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             source_collection_id: source_collection.id,
             staged: true,
             staged_quantity: 1,
             staged_foil_quantity: 0,
             staged_proxy_quantity: 0,
             staged_proxy_foil_quantity: 0,
             quantity: 0,
             foil_quantity: 0)
    end

    subject { described_class.call(card: staged_card) }

    it 'returns available quantities excluding current card' do
      result = subject
      expect(result[:regular]).to eq(4)
      expect(result[:foil]).to eq(2)
      expect(result[:proxy]).to eq(1)
      expect(result[:proxy_foil]).to eq(1)
    end
  end

  context 'when card has no source collection (planned)' do
    let!(:planned_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             source_collection_id: nil,
             staged: true,
             staged_quantity: 1,
             quantity: 0,
             foil_quantity: 0)
    end

    subject { described_class.call(card: planned_card) }

    it 'returns empty hash' do
      expect(subject).to eq({})
    end
  end
end
