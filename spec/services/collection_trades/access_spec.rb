require 'rails_helper'

RSpec.describe CollectionTrades::Access, type: :service do
  let(:owner) { create(:user, username: 'trader') }

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
    before { owner.update!(trades_public: true) }

    it 'shows it to another user' do
      expect(access(viewer: create(:user, username: 'visitor'))).to include(visible: true, owner: false)
    end

    it 'shows it when logged out' do
      expect(access(viewer: nil)).to include(visible: true, owner: false)
    end
  end
end
