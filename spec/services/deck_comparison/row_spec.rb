require 'rails_helper'

RSpec.describe DeckComparison::Row, type: :service do
  def row(quantity_a:, quantity_b:, unit_price: 2.5)
    described_class.new(magic_card: nil, board_type: 'mainboard', quantity_a: quantity_a,
                        quantity_b: quantity_b, unit_price: unit_price)
  end

  it 'labels differing counts with both numbers' do
    expect(row(quantity_a: 12, quantity_b: 9).quantity_label).to eq('12 / 9')
  end

  it 'labels equal counts with the single number' do
    expect(row(quantity_a: 1, quantity_b: 1).quantity_label).to eq('1')
  end

  it 'labels a one-sided row with that side\'s count' do
    expect(row(quantity_a: nil, quantity_b: 3).quantity_label).to eq('3')
  end

  it 'takes its quantity from A, then B' do
    expect(row(quantity_a: 12, quantity_b: 9).quantity).to eq(12)
    expect(row(quantity_a: nil, quantity_b: 9).quantity).to eq(9)
  end

  it 'is on both sides only when both quantities are present' do
    expect(row(quantity_a: 1, quantity_b: 1)).to be_both_sides
    expect(row(quantity_a: 1, quantity_b: nil)).not_to be_both_sides
  end

  it 'values the row at price times quantity' do
    expect(row(quantity_a: 4, quantity_b: nil).value).to eq(10.0)
  end

  it 'values a row with no price at zero' do
    expect(row(quantity_a: 4, quantity_b: nil, unit_price: nil).value).to eq(0.0)
  end
end
