require 'rails_helper'

RSpec.describe WantList::Upsert do
  let(:user) { create(:user) }
  let(:oracle_id) { SecureRandom.uuid }
  let(:magic_card) { create(:magic_card, scryfall_oracle_id: oracle_id) }
  let(:other_printing) { create(:magic_card, scryfall_oracle_id: oracle_id, boxset: create(:boxset)) }

  it 'creates an any-printing want for one copy by default' do
    result = described_class.call(user: user, magic_card: magic_card)

    expect(result).to include(success: true, created: true, name: magic_card.name)
    expect(result[:item]).to have_attributes(quantity: 1, foil_preference: 'any', any_printing: true)
  end

  it 'edits the row for the same printing instead of adding a second one' do
    item = create(:want_list_item, user: user, magic_card: magic_card)

    result = described_class.call(user: user, magic_card: magic_card, attributes: { quantity: 4 })

    expect(result).to include(success: true, created: false)
    expect(item.reload.quantity).to eq(4)
  end

  it 'lands an any-printing add on the any-printing row of another printing' do
    item = create(:want_list_item, user: user, magic_card: other_printing)

    result = described_class.call(user: user, magic_card: magic_card)

    expect(result[:item]).to eq(item)
  end

  it 'adds a printing-specific row alongside an any-printing row' do
    create(:want_list_item, user: user, magic_card: other_printing)

    result = described_class.call(user: user, magic_card: magic_card, attributes: { any_printing: '0' })

    expect(result).to include(success: true, created: true)
    expect(user.want_list_items.count).to eq(2)
  end

  it 'clamps the quantity to at least one' do
    result = described_class.call(user: user, magic_card: magic_card, attributes: { quantity: 0 })

    expect(result[:item].quantity).to eq(1)
  end

  it 'keeps what the row has for attributes that were not sent' do
    item = create(:want_list_item, :specific_printing, :foil, user: user, magic_card: magic_card, notes: 'nm only')

    described_class.call(user: user, item: item, attributes: { quantity: 2 })

    expect(item.reload).to have_attributes(quantity: 2, foil_preference: 'foil', any_printing: false,
                                           notes: 'nm only')
  end

  it 'explains the clash when a second row for the card is switched to any printing' do
    create(:want_list_item, user: user, magic_card: other_printing)
    item = create(:want_list_item, :specific_printing, user: user, magic_card: magic_card)

    result = described_class.call(user: user, item: item, attributes: { any_printing: '1' })

    expect(result).to eq(success: false, error: "You already want any printing of #{magic_card.name}.")
  end

  it 'rejects an unknown foil preference' do
    result = described_class.call(user: user, magic_card: magic_card, attributes: { foil_preference: 'shiny' })

    expect(result[:success]).to be(false)
  end
end
