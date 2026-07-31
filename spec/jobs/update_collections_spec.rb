require 'rails_helper'

RSpec.describe UpdateCollections, type: :job do
  let(:collection) { create(:collection, total_value: 100.0) }
  let(:card) do
    create(:magic_card, price_history: { 'normal' => history, 'foil' => [] })
  end

  before { create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1, foil_quantity: 0) }

  context 'when the history ends on the run price date' do
    let(:history) { [{ '2026-07-29' => 10.0 }, { '2026-07-30' => 8.0 }] }

    it 'applies the change' do
      described_class.perform_now(card, '2026-07-30')

      expect(collection.reload.total_value).to eq(98.0)
    end
  end

  context 'when the history has stalled on an older date' do
    # this is the drift that drained a deck below zero - the same -2.00 was
    # re-subtracted on every ingest for months because the history never moved
    let(:history) { [{ '2026-03-05' => 10.0 }, { '2026-03-06' => 8.0 }] }

    it 'leaves the collection alone' do
      described_class.perform_now(card, '2026-07-30')

      expect(collection.reload.total_value).to eq(100.0)
    end

    it 'still leaves it alone when the job runs repeatedly' do
      3.times { described_class.perform_now(card, '2026-07-30') }

      expect(collection.reload.total_value).to eq(100.0)
    end
  end

  context 'without a price date' do
    let(:history) { [{ '2026-07-29' => 10.0 }, { '2026-07-30' => 8.0 }] }

    it 'falls back to applying the change' do
      described_class.perform_now(card)

      expect(collection.reload.total_value).to eq(98.0)
    end
  end

  context 'when the card has no price history at all' do
    let(:card) { create(:magic_card, price_history: nil) }
    let(:history) { [] }

    it 'does not raise' do
      expect { described_class.perform_now(card, '2026-07-30') }.not_to raise_error
      expect(collection.reload.total_value).to eq(100.0)
    end
  end
end
