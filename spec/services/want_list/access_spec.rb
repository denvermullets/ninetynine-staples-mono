require 'rails_helper'

RSpec.describe WantList::Access, type: :service do
  let(:owner) { create(:user, username: 'wanter') }

  def access(viewer:)
    described_class.call(username: owner.username, viewer: viewer)
  end

  it 'raises for a username it does not have, so the page 404s' do
    expect { described_class.call(username: 'nobody') }.to raise_error(ActiveRecord::RecordNotFound)
  end

  context 'when the list is private' do
    it 'still shows the owner their own list' do
      expect(access(viewer: owner)).to include(visible: true, owner: true)
    end

    it 'hides it from another user' do
      expect(access(viewer: create(:user, username: 'visitor'))).to include(visible: false, owner: false)
    end

    it 'hides it when logged out' do
      expect(access(viewer: nil)).to include(visible: false, owner: false)
    end
  end

  context 'when the list is public' do
    before { owner.update!(wants_public: true) }

    it 'shows it to another user' do
      expect(access(viewer: create(:user, username: 'visitor'))).to include(visible: true, owner: false)
    end

    it 'shows it when logged out' do
      expect(access(viewer: nil)).to include(visible: true, owner: false)
    end
  end

  describe 'the collections wants are checked against' do
    let!(:public_binder) { create(:collection, user: owner, is_public: true) }
    let!(:private_binder) { create(:collection, user: owner, is_public: false) }

    before { owner.update!(wants_public: true) }

    it 'is every collection for the owner' do
      expect(access(viewer: owner)[:collection_ids]).to contain_exactly(public_binder.id, private_binder.id)
    end

    it 'is only the public ones for a visitor, so a private binder is never given away' do
      expect(access(viewer: nil)[:collection_ids]).to contain_exactly(public_binder.id)
    end
  end
end
