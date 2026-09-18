require 'rails_helper'

RSpec.describe MagicCards::TradeHolders, type: :service do
  let(:oracle_id) { SecureRandom.uuid }
  let(:bolt) do
    create(:magic_card, name: 'Lightning Bolt', scryfall_oracle_id: oracle_id, normal_price: 2, foil_price: 5)
  end
  let(:reprint) do
    create(:magic_card, name: 'Lightning Bolt', scryfall_oracle_id: oracle_id, normal_price: 1, foil_price: 3)
  end

  let(:alice) { create(:user, username: 'alice', trades_public: true) }
  let(:binder) { create(:collection, user: alice, is_public: true) }

  def holders(card: bolt, viewer: nil)
    described_class.call(card: card, viewer: viewer)
  end

  def offer(collection, card, quantity: 0, foil_quantity: 0)
    create(:collection_magic_card, collection: collection, magic_card: card,
                                   quantity: quantity, foil_quantity: foil_quantity,
                                   trade_quantity: quantity, trade_foil_quantity: foil_quantity)
  end

  it 'lists a public trader offering this printing, with the asking value per finish' do
    offer(binder, bolt, quantity: 2, foil_quantity: 1)

    holder = holders.sole

    expect([holder.user, holder.printing, holder.quantity, holder.foil_quantity]).to eq([alice, bolt, 2, 1])
    expect(holder.value).to eq(9.to_d)
  end

  it 'includes other printings of the same oracle id, after this one' do
    bob = create(:user, username: 'bob', trades_public: true)
    offer(create(:collection, user: bob, is_public: true), reprint, quantity: 10)
    offer(binder, bolt, quantity: 1)

    expect(holders.map { |row| [row.user.username, row.printing] }).to eq([['alice', bolt], ['bob', reprint]])
  end

  it 'orders other printings by asking value' do
    bob = create(:user, username: 'bob', trades_public: true)
    offer(binder, reprint, quantity: 1)
    offer(create(:collection, user: bob, is_public: true), reprint, quantity: 4)

    expect(holders.map { |row| row.user.username }).to eq(%w[bob alice])
  end

  it 'sums a trader\'s copies across their public collections' do
    offer(binder, bolt, quantity: 1)
    offer(create(:collection, user: alice, is_public: true), bolt, foil_quantity: 2)

    expect(holders.map { |row| [row.quantity, row.foil_quantity] }).to eq([[1, 2]])
  end

  it 'leaves out a user whose trade list is private' do
    offer(binder, bolt, quantity: 1)
    alice.update!(trades_public: false)

    expect(holders).to be_empty
  end

  it 'leaves out copies marked in a private collection' do
    offer(create(:collection, user: alice, is_public: false), bolt, quantity: 1)

    expect(holders).to be_empty
  end

  it 'leaves out owned copies not marked for trade' do
    create(:collection_magic_card, collection: binder, magic_card: bolt, quantity: 3)

    expect(holders).to be_empty
  end

  it 'leaves out the viewer\'s own copies' do
    offer(binder, bolt, quantity: 1)

    expect(holders(viewer: alice)).to be_empty
  end

  it 'leaves out cards of a different oracle id' do
    shock = create(:magic_card, name: 'Shock', scryfall_oracle_id: SecureRandom.uuid)
    offer(binder, shock, quantity: 1)

    expect(holders).to be_empty
  end

  it 'values a foil with no foil price at the regular price' do
    unpriced = create(:magic_card, name: 'Lightning Bolt', scryfall_oracle_id: oracle_id,
                                   normal_price: 2, foil_price: nil)
    offer(binder, unpriced, foil_quantity: 2)

    expect(holders(card: unpriced).sole.value).to eq(4.to_d)
  end
end
