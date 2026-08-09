require 'rails_helper'

RSpec.describe Collections::AggregateQuantities, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let(:magic_card) { create(:magic_card) }

  let!(:cmc) do
    create(:collection_magic_card,
           collection: collection,
           magic_card: magic_card,
           quantity: 3,
           foil_quantity: 1)
  end

  context 'with owned cards' do
    it 'returns aggregated quantities per card' do
      result = described_class.call(magic_card_ids: [magic_card.id], user: user)
      expect(result[magic_card.id][:total_quantity]).to eq(3)
      expect(result[magic_card.id][:total_foil_quantity]).to eq(1)
    end
  end

  context 'with cards across multiple collections' do
    let(:other_collection) { create(:collection, user: user) }

    before do
      create(:collection_magic_card,
             collection: other_collection,
             magic_card: magic_card,
             quantity: 2,
             foil_quantity: 0)
    end

    it 'sums quantities across collections' do
      result = described_class.call(magic_card_ids: [magic_card.id], user: user)
      expect(result[magic_card.id][:total_quantity]).to eq(5)
    end

    # the visual badge has to agree with the table's quantity column, which Search::Collection
    # already scopes to the selected collection
    it 'counts only the selected collection when given a collection_id' do
      result = described_class.call(magic_card_ids: [magic_card.id], user: user,
                                    collection_id: collection.id)

      expect(result[magic_card.id][:total_quantity]).to eq(3)
      expect(result[magic_card.id][:total_foil_quantity]).to eq(1)
    end
  end

  context "with another user's copies of the same card" do
    before do
      create(:collection_magic_card, collection: create(:collection), magic_card: magic_card, quantity: 9)
    end

    it 'ignores them' do
      result = described_class.call(magic_card_ids: [magic_card.id], user: user)
      expect(result[magic_card.id][:total_quantity]).to eq(3)
    end
  end

  context 'with no card ids' do
    it 'returns empty hash' do
      result = described_class.call(magic_card_ids: [], user: user)
      expect(result).to eq({})
    end
  end

  context 'with nil user' do
    it 'returns empty hash' do
      result = described_class.call(magic_card_ids: [magic_card.id], user: nil)
      expect(result).to eq({})
    end
  end
end
