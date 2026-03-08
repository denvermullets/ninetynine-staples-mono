require 'rails_helper'

RSpec.describe Collections::Setup, type: :service do
  let(:user) { create(:user) }

  before do
    create(:collection, user: user, name: 'Binder', collection_type: 'binder', total_value: 100.0)
    create(:collection, user: user, name: 'My Deck', collection_type: 'deck', total_value: 50.0)
  end

  context 'as the collection owner' do
    it 'returns collections and total value' do
      result = described_class.call(user: user, current_user: user)
      expect(result[:collections]).not_to be_empty
      expect(result[:collections_value]).to eq(150.0)
    end

    it 'returns a specific collection when id is provided' do
      coll = user.collections.first
      result = described_class.call(user: user, current_user: user, collection_id: coll.id)
      expect(result[:collection]).to eq(coll)
    end

    it 'filters by collection_type' do
      result = described_class.call(user: user, current_user: user, collection_type: 'deck')
      expect(result[:collections_value]).to eq(50.0)
    end

    it 'uses deck scope when requested' do
      result = described_class.call(user: user, current_user: user, use_deck_scope: true)
      expect(result[:collections_value]).to eq(50.0)
    end
  end

  context 'as a different user' do
    let(:other_user) { create(:user) }

    before do
      user.collections.first.update!(is_public: true)
      user.collections.last.update!(is_public: false)
    end

    it 'only returns public collections' do
      result = described_class.call(user: user, current_user: other_user)
      expect(result[:collections].all?(&:is_public)).to be true
    end
  end
end
