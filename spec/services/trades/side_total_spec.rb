require 'rails_helper'

RSpec.describe Trades::SideTotal, type: :service do
  def card(**prices)
    create(:magic_card, ck_buylist_normal_price: 0, ck_buylist_foil_price: 0, **prices)
  end

  def item(magic_card, quantity: 1, foil_quantity: 0)
    { magic_card_id: magic_card.id, quantity: quantity, foil_quantity: foil_quantity }
  end

  def total(items)
    described_class.call(items: items)
  end

  it 'prices each finish at its own column and counts the copies' do
    sol_ring = card(normal_price: 3, foil_price: 9, ck_buylist_normal_price: 1, ck_buylist_foil_price: 4)

    result = total([item(sol_ring, quantity: 2, foil_quantity: 1)])

    expect(result[:copies]).to eq(3)
    expect(result[:retail]).to eq(15)
    expect(result[:buylist]).to eq(6)
  end

  it 'returns BigDecimals so the totals can be summed without float drift' do
    result = total([item(card(normal_price: '0.10'), quantity: 3)])

    expect(result[:retail]).to be_a(BigDecimal).and eq('0.30'.to_d)
  end

  it 'values a foil with no foil price at the regular price' do
    unpriced_foil = card(normal_price: 4, foil_price: 0)

    expect(total([item(unpriced_foil, quantity: 0, foil_quantity: 2)])[:retail]).to eq(8)
  end

  it 'values a regular copy of a foil-only printing at the foil price' do
    foil_only = card(normal_price: 0, foil_price: 7)

    expect(total([item(foil_only, quantity: 2)])[:retail]).to eq(14)
  end

  it 'falls back the same way on the buylist' do
    no_foil_buylist = card(ck_buylist_normal_price: 2, ck_buylist_foil_price: 0)

    expect(total([item(no_foil_buylist, quantity: 0, foil_quantity: 3)])[:buylist]).to eq(6)
  end

  it 'sums the same printing listed twice' do
    sol_ring = card(normal_price: 3, foil_price: 9)

    result = total([item(sol_ring, quantity: 1), item(sol_ring, quantity: 1, foil_quantity: 1)])

    expect(result[:copies]).to eq(3)
    expect(result[:retail]).to eq(15)
  end

  it 'reads zero for no items at all' do
    expect(total([])).to eq(copies: 0, retail: 0, buylist: 0)
  end

  it 'skips a printing it cannot load and still totals the rest' do
    sol_ring = card(normal_price: 3)

    result = total([item(sol_ring), { magic_card_id: 0, quantity: 5 }, { quantity: 2 }])

    expect(result[:retail]).to eq(3)
  end
end
