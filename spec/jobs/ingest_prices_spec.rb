require 'rails_helper'

RSpec.describe IngestPrices, type: :job do
  let(:card) { create(:magic_card, card_uuid: 'abc-123', normal_price: 50.0, foil_price: 20.0) }
  let(:today) { '2026-07-31' }

  describe '#update_card' do
    it 'keeps the last known price when the feed has no entry for that finish' do
      # a retail block with only foil data used to write normal_price as 0,
      # which reads as "this card is worthless" rather than "we have no data"
      described_class.new.update_card(card.card_uuid, { 'foil' => { today => 25.0 } }, nil)

      expect(card.reload.normal_price).to eq(50.0)
      expect(card.foil_price).to eq(25.0)
    end

    it 'keeps the last known price when the feed reports zero' do
      described_class.new.update_card(card.card_uuid, { 'normal' => { today => 0.0 } }, nil)

      expect(card.reload.normal_price).to eq(50.0)
    end

    it 'records a new price when the feed has one' do
      described_class.new.update_card(card.card_uuid, { 'normal' => { today => 60.0 } }, nil)

      expect(card.reload.normal_price).to eq(60.0)
    end

    it 'falls back to zero for a card that has never had a price' do
      never_priced = create(:magic_card, card_uuid: 'no-price', normal_price: nil, foil_price: nil)

      described_class.new.update_card(never_priced.card_uuid, { 'foil' => { today => 25.0 } }, nil)

      expect(never_priced.reload.normal_price).to eq(0)
    end

    # a card whose foil listing dried up used to have its normal entry deleted
    # every day, freezing price_history at the last date both finishes shared
    it 'keeps recording normal prices when the feed has no foil data' do
      card.update!(price_history: { 'normal' => [{ '2026-03-06' => 40.0 }],
                                    'foil' => [{ '2026-03-06' => 60.0 }] })

      described_class.new.update_card(card.card_uuid, { 'normal' => { today => 55.0 } }, nil)

      normal_dates = card.reload.price_history['normal'].map { |entry| entry.keys.first }
      expect(normal_dates).to eq(['2026-03-06', today])
      expect(card.price_history['foil'].map { |entry| entry.keys.first }).to eq(['2026-03-06'])
    end

    it 'records the first price point for a card with no history' do
      described_class.new.update_card(card.card_uuid, { 'normal' => { today => 55.0 } }, nil)

      expect(card.reload.price_history['normal']).to eq([{ today => 55.0 }])
    end

    it 'keeps the last known buylist price when the feed has no entry' do
      card.update!(ck_buylist_normal_price: 30.0)

      described_class.new.update_card(card.card_uuid, nil, { 'foil' => { today => 12.0 } })

      expect(card.reload.ck_buylist_normal_price).to eq(30.0)
      expect(card.ck_buylist_foil_price).to eq(12.0)
    end
  end
end
