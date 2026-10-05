require 'rails_helper'

RSpec.describe MagicCards::PriceChange, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  let(:price_history) do
    {
      'normal' => [{ '2026-07-24' => 10.0 }, { '2026-07-30' => 40.0 }],
      'foil' => [{ '2026-07-24' => 20.0 }, { '2026-07-30' => 25.0 }]
    }
  end

  around { |example| travel_to(Date.parse('2026-07-31')) { example.run } }

  it 'measures each finish against the entry on or before the given number of days ago' do
    expect(described_class.call(price_history, 50.0, 30.0, days: 1)).to eq([25.0, 20.0])
    expect(described_class.call(price_history, 50.0, 30.0, days: 7)).to eq([400.0, 50.0])
  end

  it 'reads history built with symbol keys the same as rows loaded from the db' do
    symbolized = { normal: price_history['normal'], foil: price_history['foil'] }

    expect(described_class.call(symbolized, 50.0, 30.0, days: 1)).to eq([25.0, 20.0])
  end

  it 'returns nils when there is no history' do
    expect(described_class.call(nil, 50.0, 30.0, days: 1)).to eq([nil, nil])
    expect(described_class.call({}, 50.0, 30.0, days: 1)).to eq([nil, nil])
  end

  it 'returns nil for a finish with nothing old enough to compare against' do
    expect(described_class.call(price_history, 50.0, 30.0, days: 30)).to eq([nil, nil])
  end

  it 'returns nil when the old price is zero' do
    history = { 'normal' => [{ '2026-07-30' => 0.0 }], 'foil' => [] }

    expect(described_class.call(history, 50.0, 30.0, days: 1)).to eq([nil, nil])
  end
end
