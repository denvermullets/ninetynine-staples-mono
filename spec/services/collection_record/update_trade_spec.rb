require 'rails_helper'

RSpec.describe CollectionRecord::UpdateTrade, type: :service do
  let(:record) { create(:collection_magic_card, quantity: 3, foil_quantity: 1) }

  def call(trade_quantity:, trade_foil_quantity:, card: record)
    described_class.call(collection_magic_card: card, trade_quantity:, trade_foil_quantity:)
  end

  it 'sets the regular and foil trade counts' do
    result = call(trade_quantity: 2, trade_foil_quantity: 1)

    expect(result).to include(success: true, name: record.magic_card.name)
    expect(record.reload).to have_attributes(trade_quantity: 2, trade_foil_quantity: 1)
  end

  it 'caps counts at the owned copies' do
    call(trade_quantity: 10, trade_foil_quantity: 5)

    expect(record.reload).to have_attributes(trade_quantity: 3, trade_foil_quantity: 1)
  end

  it 'floors negative and blank counts at zero' do
    record.update!(trade_quantity: 2, trade_foil_quantity: 1)
    call(trade_quantity: -4, trade_foil_quantity: nil)

    expect(record.reload).to have_attributes(trade_quantity: 0, trade_foil_quantity: 0)
  end

  it 'refuses staged rows' do
    staged = create(:collection_magic_card, quantity: 2, staged: true)

    expect(call(card: staged, trade_quantity: 1, trade_foil_quantity: 0)).to include(success: false)
    expect(staged.reload.trade_quantity).to eq(0)
  end

  it 'refuses needed rows' do
    needed = create(:collection_magic_card, quantity: 2, needed: true)

    expect(call(card: needed, trade_quantity: 1, trade_foil_quantity: 0)).to include(success: false)
    expect(needed.reload.trade_quantity).to eq(0)
  end
end
