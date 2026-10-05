require 'rails_helper'

RSpec.describe BackfillPriceChangeDaily, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  around { |example| travel_to(Date.parse('2026-07-31')) { example.run } }

  before { allow($stdout).to receive(:puts) }

  it 'fills the daily change for cards with price history' do
    card = create(:magic_card, normal_price: 50.0, foil_price: 30.0,
                               price_history: { 'normal' => [{ '2026-07-30' => 40.0 }],
                                                'foil' => [{ '2026-07-30' => 25.0 }] })

    described_class.perform_now

    expect(card.reload.price_change_daily_normal).to eq(25.0)
    expect(card.price_change_daily_foil).to eq(20.0)
  end

  it 'skips cards with no price history' do
    card = create(:magic_card, normal_price: 50.0, price_history: nil, price_change_daily_normal: 5.0)

    described_class.perform_now

    expect(card.reload.price_change_daily_normal).to eq(5.0)
  end

  it 'leaves the weekly change alone' do
    card = create(:magic_card, normal_price: 50.0, price_change_weekly_normal: 7.5,
                               price_history: { 'normal' => [{ '2026-07-30' => 40.0 }], 'foil' => [] })

    described_class.perform_now

    expect(card.reload.price_change_weekly_normal).to eq(7.5)
  end
end
