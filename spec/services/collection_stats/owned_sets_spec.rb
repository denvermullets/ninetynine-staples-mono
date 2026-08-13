require 'rails_helper'

RSpec.describe CollectionStats::OwnedSets, type: :service do
  subject(:sets) { described_class.call(collection_ids: [collection.id]) }

  let(:collection) { create(:collection) }

  def own(boxset, **attributes)
    card = create(:magic_card, boxset: boxset, card_number: '1')
    create(:collection_magic_card, { collection: collection, magic_card: card,
                                     quantity: 1 }.merge(attributes))
  end

  it 'lists the sets the collection has a real card from' do
    own(create(:boxset, name: 'Alpha'))
    create(:boxset, name: 'Untouched')

    expect(sets.map(&:name)).to eq(['Alpha'])
  end

  it 'names each set once however many cards of it are held' do
    alpha = create(:boxset, name: 'Alpha')
    3.times { own(alpha) }

    expect(sets.map(&:name)).to eq(['Alpha'])
  end

  # the picker navigates between rows of the completion panel, so it must not offer a set that
  # panel does not list - a proxied set is a dead end there
  it 'leaves out a set held entirely in proxies' do
    own(create(:boxset, name: 'Alpha'))
    own(create(:boxset, name: 'Proxied'), quantity: 0, proxy_quantity: 4)

    expect(sets.map(&:name)).to eq(['Alpha'])
  end

  it 'ignores staged and wishlist rows, same as the rest of the dashboard' do
    own(create(:boxset, name: 'Staged'), staged: true)
    own(create(:boxset, name: 'Wanted'), needed: true)

    expect(sets).to be_empty
  end

  # newest first: somebody opening a set picker is usually going somewhere recent
  it 'puts the most recent set at the top' do
    own(create(:boxset, name: 'Old', release_date: '1993-08-05'))
    own(create(:boxset, name: 'New', release_date: '2024-08-02'))
    own(create(:boxset, name: 'Undated', release_date: nil))

    expect(sets.map(&:name)).to eq(%w[New Old Undated])
  end

  it 'returns nothing when there are no collections' do
    expect(described_class.call(collection_ids: [])).to be_empty
  end
end
