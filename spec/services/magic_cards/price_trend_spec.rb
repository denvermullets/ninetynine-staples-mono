require 'rails_helper'

RSpec.describe MagicCards::PriceTrend, type: :service do
  let(:price_history) do
    {
      'normal' => [
        { '2026-02-01' => 5.0 },
        { '2026-02-02' => 5.5 },
        { '2026-02-03' => 6.0 },
        { '2026-02-04' => 6.5 },
        { '2026-02-05' => 7.0 },
        { '2026-02-06' => 7.5 },
        { '2026-02-07' => 8.0 }
      ],
      'foil' => [
        { '2026-02-01' => 10.0 },
        { '2026-02-07' => 10.5 }
      ]
    }
  end

  describe '#call' do
    it 'returns trend data for each price type' do
      result = described_class.new(price_history).call
      expect(result).to be_a(Hash)
    end

    it 'returns empty hash when price_history is nil' do
      result = described_class.new(nil).call
      expect(result).to eq({})
    end

    it 'returns empty hash when price_history is empty' do
      result = described_class.new({}).call
      expect(result).to eq({})
    end
  end

  describe '#price_change' do
    it 'calculates change between last two prices' do
      result = described_class.new(price_history).price_change
      expect(result['normal'][:old_price]).to eq(7.5)
      expect(result['normal'][:new_price]).to eq(8.0)
      expect(result['normal'][:change]).to eq(0.5)
    end

    it 'returns empty hash with insufficient data' do
      result = described_class.new({ 'normal' => [{ '2026-02-01' => 5.0 }] }).price_change
      expect(result).to eq({})
    end
  end

  describe '#trend' do
    context 'when price increased significantly' do
      let(:trending_history) do
        {
          'normal' => [
            { '2026-02-01' => 1.0 },
            { '2026-02-07' => 2.0 }
          ]
        }
      end

      it 'returns up trend' do
        result = described_class.new(trending_history).trend(days: 7, threshold_percent: 5.0)
        expect(result[:normal]).to eq('up')
      end
    end

    context 'when price decreased significantly' do
      let(:declining_history) do
        {
          'normal' => [
            { '2026-02-01' => 10.0 },
            { '2026-02-07' => 5.0 }
          ]
        }
      end

      it 'returns down trend' do
        result = described_class.new(declining_history).trend(days: 7, threshold_percent: 5.0)
        expect(result[:normal]).to eq('down')
      end
    end

    context 'when price is stable' do
      let(:stable_history) do
        {
          'normal' => [
            { '2026-02-01' => 10.0 },
            { '2026-02-07' => 10.01 }
          ]
        }
      end

      it 'returns nil trend' do
        result = described_class.new(stable_history).trend(days: 7, threshold_percent: 5.0)
        expect(result[:normal]).to be_nil
      end
    end
  end
end
