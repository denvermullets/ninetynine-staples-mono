require 'rails_helper'

RSpec.describe Decks::Listing, type: :service do
  let(:user) { create(:user) }

  def deck(name, **attrs)
    create(:collection, user: user, name: name, collection_type: 'commander_deck', is_public: true, **attrs)
  end

  def names(listing) = listing.decks.map(&:name)

  it 'sorts by the requested option and falls back to recently updated' do
    deck('B', updated_at: 2.days.ago)
    deck('A', updated_at: 1.day.ago)

    expect(names(described_class.call(user: user, viewer: user, sort: 'name_desc'))).to eq(%w[B A])
    expect(names(described_class.call(user: user, viewer: user, sort: 'nonsense'))).to eq(%w[A B])
  end

  it 'hides private decks from everyone but the owner' do
    deck('Open')
    deck('Secret', is_public: false)

    expect(names(described_class.call(user: user, viewer: user))).to contain_exactly('Open', 'Secret')
    expect(names(described_class.call(user: user, viewer: create(:user)))).to eq(['Open'])
  end

  it 'leaves out a deck that is being deleted, groups included' do
    keep = deck('Keep')
    gone = deck('Gone')

    listing = described_class.call(user: user, viewer: user, group_by: 'tag', exclude_id: gone.id)

    expect(listing.decks).to eq([keep])
    expect(listing.groups.flat_map(&:decks)).to eq([keep])
  end

  it 'ignores an unknown grouping' do
    expect(described_class.call(user: user, viewer: user, group_by: 'nope').group_by).to eq('none')
  end
end
