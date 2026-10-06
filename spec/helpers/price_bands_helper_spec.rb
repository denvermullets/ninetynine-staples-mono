require 'rails_helper'

RSpec.describe PriceBandsHelper, type: :helper do
  let(:user) { create(:user) }

  def band(**attributes)
    build(:price_alert, :band, user: user, **attributes)
  end

  describe '#price_band_condition' do
    it 'reads an above band from its from price up to its threshold' do
      expect(helper.price_band_condition(band)).to eq('$0.90 or less to $1.00 or more, any finish')
    end

    it 'reads a two-way band as both moves' do
      expect(helper.price_band_condition(band(direction: 'both')))
        .to eq('Up to $1.00 or more, or back to $0.90 or less, any finish')
    end

    it 'reads a below band the other way up, with its finish and buylist range' do
      alert = band(direction: 'below', from_price: 1.1, finish: 'foil', min_buylist_price: 0.25)

      expect(helper.price_band_condition(alert)).to eq('$1.10 or more to under $1.00, foil, CK buylist $0.25+')
    end
  end

  describe '#price_band_move_heading' do
    it 'heads each way a card can go' do
      both = band(direction: 'both')

      expect(helper.price_band_move_heading(both, 'up')).to eq('Went up to $1.00 or more')
      expect(helper.price_band_move_heading(both, 'down')).to eq('Dropped back to $0.90 or less')
      expect(helper.price_band_move_heading(band(direction: 'below', from_price: 1.1), 'down'))
        .to eq('Dropped under $1.00')
    end
  end

  describe '#price_alert_buylist_range' do
    it 'reads either end, both, or nothing' do
      expect(helper.price_alert_buylist_range(band)).to be_nil
      expect(helper.price_alert_buylist_range(band(max_buylist_price: 2))).to eq('CK buylist up to $2.00')
      expect(helper.price_alert_buylist_range(band(min_buylist_price: 0.25, max_buylist_price: 2)))
        .to eq('CK buylist $0.25-$2.00')
    end
  end

  it 'lists where a card is' do
    expect(helper.price_band_places([{ name: 'Binder', copies: 2 }, { name: 'Box', copies: 1 }]))
      .to eq('Binder ×2, Box ×1')
    expect(helper.price_band_places([])).to eq('No longer in this collection')
  end

  it 'shows a price CK is not paying as a dash' do
    expect(helper.price_band_money(BigDecimal('0'))).to eq('-')
    expect(helper.price_band_money(nil)).to eq('-')
    expect(helper.price_band_money(BigDecimal('1.5'))).to eq('$1.50')
  end
end
