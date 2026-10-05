require 'rails_helper'

RSpec.describe CollectionMoversHelper, type: :helper do
  let(:filters) do
    { window: 'weekly', direction: 'both', finish: 'both', min_delta: BigDecimal('5'),
      min_percent: BigDecimal('12.5'), min_price: nil, sort: 'delta', dir: 'desc' }
  end

  describe '#movers_amount' do
    it 'reads as a plain number rather than BigDecimal notation' do
      expect(helper.movers_amount(BigDecimal('5'))).to eq('5')
      expect(helper.movers_amount(BigDecimal('12.5'))).to eq('12.5')
      expect(helper.movers_amount(nil)).to be_nil
    end
  end

  describe '#movers_query' do
    it 'carries the filters as plain values and drops the unset ones' do
      expect(helper.movers_query(filters, 7, sort: 'name')).to eq(
        window: 'weekly', direction: 'both', finish: 'both', min_delta: '5', min_percent: '12.5',
        sort: 'name', dir: 'desc', collection_id: 7
      )
    end

    it 'leaves collection_id off for the whole collection' do
      expect(helper.movers_query(filters, nil)).not_to have_key(:collection_id)
    end
  end

  describe '#movers_sort_dir' do
    it 'flips the direction of the active column' do
      expect(helper.movers_sort_dir('delta', filters)).to eq('asc')
      expect(helper.movers_sort_dir('delta', filters.merge(dir: 'asc'))).to eq('desc')
    end

    it 'starts another column at its natural direction' do
      expect(helper.movers_sort_dir('name', filters)).to eq('asc')
      expect(helper.movers_sort_dir('value', filters)).to eq('desc')
    end
  end

  describe '#movers_unit_price' do
    let(:row) { { qty: 0, foil_qty: 2, normal_price: BigDecimal('1'), foil_price: BigDecimal('30') } }

    it 'prices only the finishes actually held' do
      expect(helper.movers_unit_price(row)).to eq('$30.00 foil')
      expect(helper.movers_unit_price(row.merge(qty: 1))).to eq('$1.00 / $30.00 foil')
    end
  end

  describe '#movers_delta and #movers_percent' do
    it 'signs both moves' do
      row = { delta: BigDecimal('-4.5'), percent: -10.0 }

      expect(helper.movers_delta(row)).to eq('-$4.50')
      expect(helper.movers_percent(row)).to eq('-10.0%')
      expect(helper.movers_percent(row.merge(percent: 3.2))).to eq('+3.2%')
    end
  end

  describe '#movers_alert_params' do
    it 'posts the rule as plain values with the unset ones dropped' do
      attributes = PriceAlert.movement_rule_attributes(filters, collection_id: 7)

      expect(helper.movers_alert_params(attributes)).to eq(
        kind: 'movement', collection_id: 7, window: 'weekly', direction: 'both', finish: 'any',
        min_delta_amount: '5', min_delta_percent: '12.5'
      )
    end
  end

  describe '#movers_alert_ready?' do
    it 'needs a minimum move in dollars or percent' do
      ready = ->(changes) { helper.movers_alert_ready?(PriceAlert.movement_rule_attributes(filters.merge(changes))) }

      expect(ready.call(min_percent: nil)).to be(true)
      expect(ready.call(min_delta: nil)).to be(true)
      expect(ready.call(min_delta: nil, min_percent: nil, min_price: BigDecimal('3'))).to be(false)
    end
  end
end
