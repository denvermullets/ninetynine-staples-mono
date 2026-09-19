require 'rails_helper'

RSpec.describe WantList::ProxyImport, type: :service do
  let(:user) { create(:user) }
  let(:binder) { create(:collection, user: user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }

  def card(name, oracle_id: SecureRandom.uuid, **attributes)
    create(:magic_card, name: name, scryfall_oracle_id: oracle_id, **attributes)
  end

  def hold(magic_card, collection: binder, quantity: 0, **quantities)
    create(:collection_magic_card, collection: collection, magic_card: magic_card, quantity: quantity, **quantities)
  end

  it 'adds an any-printing want for each proxied card' do
    seas = card('Underground Sea')
    hold(seas, proxy_quantity: 1)

    result = described_class.call(user: user)

    expect(result[:added].map(&:magic_card)).to eq([seas])
    expect(user.want_list_items.first).to have_attributes(quantity: 1, any_printing: true, foil_preference: 'any')
  end

  it 'counts proxies of every finish and printing, in binders and decks, as one want' do
    oracle_id = SecureRandom.uuid
    hold(card('Underground Sea', oracle_id: oracle_id), proxy_quantity: 1, proxy_foil_quantity: 1)
    hold(card('Underground Sea', oracle_id: oracle_id), collection: deck, proxy_quantity: 2)

    result = described_class.call(user: user)

    expect(result[:added].map(&:quantity)).to eq([4])
  end

  it 'wants every proxy, however many real copies are owned' do
    oracle_id = SecureRandom.uuid
    hold(card('Underground Sea', oracle_id: oracle_id), quantity: 1, proxy_quantity: 3)
    hold(card('Underground Sea', oracle_id: oracle_id), quantity: 4)

    expect(described_class.call(user: user)[:added].map(&:quantity)).to eq([3])
  end

  it 'leaves a card that is already wanted as it was' do
    seas = card('Underground Sea')
    hold(seas, proxy_quantity: 2)
    want = create(:want_list_item, user: user, magic_card: seas, quantity: 1)

    result = described_class.call(user: user)

    expect(result[:added]).to be_empty
    expect(result[:already_wanted]).to be_empty
    expect(want.reload.quantity).to eq(1)
  end

  it "ignores staged rows, needed rows and other users' proxies" do
    hold(card('Staged'), proxy_quantity: 0, staged: true, staged_proxy_quantity: 1)
    hold(card('Needed'), proxy_quantity: 1, needed: true)
    hold(card('Theirs'), collection: create(:collection), proxy_quantity: 1)

    expect(described_class.call(user: user)[:added]).to be_empty
  end

  it 'adds nothing for a user with no proxies' do
    hold(card('Sol Ring'), quantity: 1)

    expect(described_class.call(user: user)).to include(success: true, added: [])
  end
end
