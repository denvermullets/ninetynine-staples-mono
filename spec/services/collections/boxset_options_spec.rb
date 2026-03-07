require 'rails_helper'

RSpec.describe Collections::BoxsetOptions, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let(:boxset) { create(:boxset, keyrune_code: 'TST') }
  let(:magic_card) { create(:magic_card, boxset: boxset) }

  before do
    create(:collection_magic_card, collection: collection, magic_card: magic_card, quantity: 1, foil_quantity: 0)
  end

  context 'for a specific collection' do
    it 'returns boxsets present in that collection' do
      result = described_class.call(collections: user.collections, collection_id: collection.id)
      expect(result.size).to eq(1)
      expect(result.first[:code]).to eq(boxset.code)
      expect(result.first[:keyrune_code]).to eq('tst')
    end
  end

  context 'across all collections' do
    it 'returns boxsets from all user collections' do
      result = described_class.call(collections: user.collections)
      expect(result.size).to eq(1)
    end
  end

  context 'when no cards exist' do
    it 'returns empty array' do
      empty_collection = create(:collection, user: user)
      result = described_class.call(collections: Collection.where(id: empty_collection.id))
      expect(result).to be_empty
    end
  end
end
