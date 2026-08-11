require 'rails_helper'

RSpec.describe CollectionStats::Scope, type: :service do
  let(:user) { create(:user, username: 'owner') }
  let(:stranger) { create(:user, username: 'stranger') }
  let!(:public_collection) { create(:collection, user: user, is_public: true) }
  let!(:private_collection) { create(:collection, user: user, is_public: false) }

  describe 'as the owner' do
    subject(:scope) { described_class.call(username: user.username, viewer: user) }

    it 'sees every collection' do
      expect(scope[:collection_ids]).to match_array([public_collection.id, private_collection.id])
    end

    it 'reports ownership' do
      expect(scope[:owner]).to be(true)
    end

    it 'can narrow to its own private collection' do
      scoped = described_class.call(username: user.username, viewer: user,
                                    collection_id: private_collection.id)

      expect(scoped[:collection_ids]).to eq([private_collection.id])
      expect(scoped[:missing]).to be(false)
    end
  end

  describe 'as a visitor' do
    subject(:scope) { described_class.call(username: user.username, viewer: nil) }

    it 'sees only public collections' do
      expect(scope[:collection_ids]).to eq([public_collection.id])
    end

    it 'does not report ownership' do
      expect(scope[:owner]).to be(false)
    end

    it 'refuses to narrow to a private collection' do
      scoped = described_class.call(username: user.username, viewer: nil,
                                    collection_id: private_collection.id)

      expect(scoped[:missing]).to be(true)
      expect(scoped[:collection_ids]).to be_empty
    end

    it 'refuses even when another signed-in user asks' do
      scoped = described_class.call(username: user.username, viewer: stranger,
                                    collection_id: private_collection.id)

      expect(scoped[:missing]).to be(true)
    end
  end

  # CollectionsController#enforce_visibility resolves with a bare Collection.find_by(id:) and
  # never checks the collection belongs to the user in the URL. This one does.
  describe 'a collection id belonging to somebody else' do
    it 'is treated as missing rather than reported on' do
      theirs = create(:collection, user: stranger, is_public: true)

      scope = described_class.call(username: user.username, viewer: user, collection_id: theirs.id)

      expect(scope[:missing]).to be(true)
      expect(scope[:collection_ids]).to be_empty
    end
  end

  describe 'history' do
    it 'returns the selected collection\'s own series' do
      public_collection.update!(collection_history: { '2026-01-01' => 10.0 })

      scope = described_class.call(username: user.username, viewer: user,
                                   collection_id: public_collection.id)

      expect(scope[:history]).to eq({ '2026-01-01' => 10.0 })
    end

    it 'aggregates across collections when none is selected' do
      public_collection.update!(collection_history: { '2026-01-01' => 10.0 })
      private_collection.update!(collection_history: { '2026-01-01' => 5.0 })

      scope = described_class.call(username: user.username, viewer: user)

      expect(scope[:history]['2026-01-01']).to eq(15.0)
    end

    it 'aggregates only visible collections for a visitor' do
      public_collection.update!(collection_history: { '2026-01-01' => 10.0 })
      private_collection.update!(collection_history: { '2026-01-01' => 5.0 })

      scope = described_class.call(username: user.username, viewer: nil)

      expect(scope[:history]['2026-01-01']).to eq(10.0)
    end
  end

  describe 'an unknown username' do
    it 'raises so the request 404s' do
      expect { described_class.call(username: 'nobodyhere') }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
