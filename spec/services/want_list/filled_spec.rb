require 'rails_helper'

RSpec.describe WantList::Filled, type: :service do
  let(:user) { create(:user) }
  let(:binder) { create(:collection, user: user) }
  let(:oracle_id) { SecureRandom.uuid }
  let(:card) { create(:magic_card, name: 'Mox Diamond', scryfall_oracle_id: oracle_id) }
  let(:other_printing) { create(:magic_card, name: 'Mox Diamond', scryfall_oracle_id: oracle_id) }

  # the copies are saved first, the way callers ask after their own update
  def add(magic_card, quantity: 0, foil_quantity: 0)
    record = binder.collection_magic_cards.find_or_initialize_by(magic_card: magic_card)
    record.update!(quantity: record.quantity.to_i + quantity, foil_quantity: record.foil_quantity.to_i + foil_quantity)

    described_class.call(user: user, additions: { magic_card => { quantity:, foil_quantity: } })
  end

  it 'returns a want the new copy fills' do
    want = create(:want_list_item, user: user, magic_card: card)

    expect(add(card, quantity: 1)).to contain_exactly(want)
  end

  it 'counts another printing toward an any-printing want' do
    want = create(:want_list_item, user: user, magic_card: card)

    expect(add(other_printing, quantity: 1)).to contain_exactly(want)
  end

  it 'leaves out a specific-printing want for another printing' do
    create(:want_list_item, :specific_printing, user: user, magic_card: card)

    expect(add(other_printing, quantity: 1)).to be_empty
  end

  it 'leaves out a want the copies do not cover yet' do
    create(:want_list_item, user: user, magic_card: card, quantity: 4)

    expect(add(card, quantity: 2)).to be_empty
  end

  it 'returns the want once the last copy it needed arrives' do
    want = create(:want_list_item, user: user, magic_card: card, quantity: 2)
    add(card, quantity: 1)

    expect(add(card, quantity: 1)).to contain_exactly(want)
  end

  it 'leaves out a want that was already filled before these copies' do
    create(:want_list_item, user: user, magic_card: card)
    add(card, quantity: 1)

    expect(add(card, quantity: 1)).to be_empty
  end

  it 'does not let a non-foil copy fill a foil-only want' do
    create(:want_list_item, :foil, user: user, magic_card: card)

    expect(add(card, quantity: 1)).to be_empty
  end

  it 'lets a foil copy fill a foil-only want' do
    want = create(:want_list_item, :foil, user: user, magic_card: card)

    expect(add(card, foil_quantity: 1)).to contain_exactly(want)
  end

  it 'counts copies in any of the user\'s collections' do
    want = create(:want_list_item, user: user, magic_card: card, quantity: 2)
    create(:collection_magic_card, collection: create(:collection, user: user), magic_card: card, quantity: 1)

    expect(add(card, quantity: 1)).to contain_exactly(want)
  end

  it "ignores other users' wants" do
    create(:want_list_item, magic_card: card)

    expect(add(card, quantity: 1)).to be_empty
  end

  it 'returns nothing when no copies were added' do
    create(:want_list_item, user: user, magic_card: card)
    create(:collection_magic_card, collection: binder, magic_card: card, quantity: 1)

    result = described_class.call(user: user, additions: { card => { quantity: -1, foil_quantity: 0 } })

    expect(result).to be_empty
  end

  it 'sums a card added under more than one key' do
    want = create(:want_list_item, user: user, magic_card: card, quantity: 2)
    create(:collection_magic_card, collection: binder, magic_card: card, quantity: 1)
    create(:collection_magic_card, collection: binder, magic_card: other_printing, quantity: 1)

    result = described_class.call(
      user: user, additions: { card => { quantity: 1 }, other_printing => { quantity: 1 } }
    )

    expect(result).to contain_exactly(want)
  end
end
