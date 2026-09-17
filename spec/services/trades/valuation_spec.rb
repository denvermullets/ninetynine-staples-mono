require 'rails_helper'

RSpec.describe Trades::Valuation, type: :service do
  let(:trade) { create(:trade) }

  def card(**prices)
    create(:magic_card, ck_buylist_normal_price: 0, ck_buylist_foil_price: 0, **prices)
  end

  # snapshots default to whatever the card is worth now, so a trade reads as un-drifted unless a spec
  # moves the price afterwards
  def offer(side, magic_card, quantity: 1, foil_quantity: 0, **snapshots)
    create(:trade_item, trade: trade, magic_card: magic_card, side: side,
                        quantity: quantity, foil_quantity: foil_quantity,
                        unit_price_snapshot: magic_card.normal_price,
                        unit_foil_price_snapshot: magic_card.foil_price,
                        unit_buylist_snapshot: magic_card.ck_buylist_normal_price,
                        unit_buylist_foil_snapshot: magic_card.ck_buylist_foil_price, **snapshots)
  end

  def valuation
    described_class.call(trade: trade.reload)
  end

  describe 'a freshly proposed trade' do
    before do
      offer('proposer', card(normal_price: 3, foil_price: 9, ck_buylist_normal_price: 1, ck_buylist_foil_price: 4),
            quantity: 2, foil_quantity: 1)
      offer('recipient', card(normal_price: 10, ck_buylist_normal_price: 5), quantity: 1)
    end

    it 'totals each side live and at the snapshot, which agree until a price moves' do
      result = valuation

      expect(result[:proposer]).to include(copies: 3, retail: 15, buylist: 6, retail_snapshot: 15,
                                           buylist_snapshot: 6)
      expect(result[:recipient]).to include(copies: 1, retail: 10, buylist: 5, retail_snapshot: 10,
                                            buylist_snapshot: 5)
    end

    it 'reports the gap as recipient minus proposer' do
      result = valuation

      expect(result[:difference]).to eq(-5)
      expect(result[:live_difference]).to eq(-5)
    end

    it 'reads positive when the recipient is putting up more value' do
      offer('recipient', card(normal_price: 20), quantity: 1)

      expect(valuation[:difference]).to eq(15)
    end

    it 'is not drifting' do
      expect(valuation[:drift?]).to be(false)
      expect(valuation[:proposer][:drift?]).to be(false)
    end
  end

  describe 'drift' do
    it 'flags a side whose live retail has moved past 5% of a large snapshot' do
      spiking = card(normal_price: 100)
      offer('proposer', spiking)
      spiking.update!(normal_price: 106)

      result = valuation

      expect(result[:proposer]).to include(retail: 106, retail_snapshot: 100, drift?: true)
      expect(result[:drift?]).to be(true)
    end

    it 'leaves a move inside 5% of a large snapshot alone' do
      drifting = card(normal_price: 100)
      offer('proposer', drifting)
      drifting.update!(normal_price: 104)

      expect(valuation[:drift?]).to be(false)
    end

    it 'leaves a sub-dollar move on a cheap side alone, however large a percentage it is' do
      bulk = card(normal_price: 3)
      offer('proposer', bulk)
      bulk.update!(normal_price: '3.50')

      expect(valuation[:proposer]).to include(retail: '3.50'.to_d, drift?: false)
    end

    it 'flags a dollar-plus move on a cheap side' do
      bulk = card(normal_price: 3)
      offer('proposer', bulk)
      bulk.update!(normal_price: 5)

      expect(valuation[:drift?]).to be(true)
    end

    it 'flags a drop as readily as a spike' do
      crashing = card(normal_price: 40)
      offer('proposer', crashing)
      crashing.update!(normal_price: 30)

      expect(valuation[:drift?]).to be(true)
    end

    it 'flags the trade when only the recipient side has drifted' do
      steady = card(normal_price: 5)
      moving = card(normal_price: 50)
      offer('proposer', steady)
      offer('recipient', moving)
      moving.update!(normal_price: 60)

      result = valuation

      expect(result[:proposer][:drift?]).to be(false)
      expect(result[:recipient][:drift?]).to be(true)
      expect(result[:drift?]).to be(true)
    end

    it 'ignores buylist movement - the headline number is retail' do
      card_with_buylist = card(normal_price: 10, ck_buylist_normal_price: 5)
      offer('proposer', card_with_buylist)
      card_with_buylist.update!(ck_buylist_normal_price: 1)

      expect(valuation[:proposer]).to include(buylist: 1, buylist_snapshot: 5, drift?: false)
    end
  end

  describe 'edges' do
    it 'reads zero for a side offering nothing - a wishlist-style one-way trade' do
      offer('proposer', card(normal_price: 4))

      expect(valuation[:recipient]).to eq(copies: 0, retail: 0, buylist: 0, retail_snapshot: 0,
                                          buylist_snapshot: 0, drift?: false)
    end

    it 'values a foil snapshot that was never recorded at the regular snapshot' do
      offer('proposer', card(normal_price: 4, foil_price: 0), quantity: 0, foil_quantity: 2)

      expect(valuation[:proposer]).to include(retail_snapshot: 8, retail: 8, drift?: false)
    end

    it 'keeps the snapshot when the binder row behind an item is deleted' do
      row = create(:collection_magic_card, magic_card: card(normal_price: 6))
      item = offer('proposer', row.magic_card)
      item.update!(collection_magic_card: row)
      row.destroy

      expect(valuation[:proposer]).to include(retail_snapshot: 6, retail: 6)
    end
  end
end
