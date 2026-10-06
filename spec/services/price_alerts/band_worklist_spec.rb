require 'rails_helper'

RSpec.describe PriceAlerts::BandWorklist do
  let(:user) { create(:user) }
  let(:binder) { create(:collection, user: user, name: 'Binder') }
  let(:trade_box) { create(:collection, user: user, name: 'Trade Box') }
  let(:band) { create(:price_alert, :band, user: user) }

  def card(name, **attributes)
    create(:magic_card, name: name, normal_price: 1.2, foil_price: 4, ck_buylist_normal_price: 0.4, **attributes)
  end

  def hold(magic_card, collection, quantity: 1, foil_quantity: 0, **attributes)
    create(:collection_magic_card, collection: collection, magic_card: magic_card, quantity: quantity,
                                   foil_quantity: foil_quantity, **attributes)
  end

  it 'lists the cards to do binder by binder, then by name, with where each one is' do
    zed = card('Zed')
    able = card('Able')
    traded = card('Traded')
    [zed, able].each { |magic_card| hold(magic_card, binder, quantity: 2) }
    hold(able, trade_box)
    hold(traded, trade_box)
    [zed, able, traded].each { |magic_card| create(:price_band_card, :to_do, band: band, magic_card: magic_card) }

    rows = described_class.call(band: band)

    expect(rows.map { |row| row[:card].name }).to eq(%w[Able Zed Traded])
    expect(rows.first[:places]).to eq([{ name: 'Binder', copies: 2 }, { name: 'Trade Box', copies: 1 }])
    expect(rows.first).to include(price: BigDecimal('1.2'), buylist: BigDecimal('0.4'))
  end

  it 'prices and places a foil row on the foil copies alone' do
    shiny = card('Shiny', ck_buylist_foil_price: 2)
    hold(shiny, binder, quantity: 1)
    hold(shiny, trade_box, quantity: 0, foil_quantity: 1)
    create(:price_band_card, :to_do, band: band, magic_card: shiny, finish: 'foil')

    row = described_class.call(band: band).sole

    expect(row).to include(price: 4, buylist: 2, places: [{ name: 'Trade Box', copies: 1 }])
  end

  it 'leaves out staged, wanted and proxy-only places' do
    staged = card('Staged')
    hold(staged, binder, staged: true)
    hold(staged, trade_box, quantity: 0, proxy_quantity: 1)
    create(:price_band_card, :to_do, band: band, magic_card: staged)

    expect(described_class.call(band: band).sole[:places]).to be_empty
  end

  it 'puts the moves up ahead of the moves down' do
    down = card('Aaa Faller')
    up = card('Zzz Riser')
    [down, up].each { |magic_card| hold(magic_card, binder) }
    create(:price_band_card, :to_do, band: band, magic_card: down, moved: 'down', state: 'armed')
    create(:price_band_card, :to_do, band: band, magic_card: up)

    expect(described_class.call(band: band).map { |row| row[:card] }).to eq([up, down])
  end

  it 'shows the done tab newest first, and nothing still to do' do
    older = create(:price_band_card, :done, band: band, handled_at: 2.days.ago)
    newer = create(:price_band_card, :done, band: band, handled_at: 1.hour.ago)
    create(:price_band_card, :to_do, band: band)
    create(:price_band_card, band: band)

    expect(described_class.call(band: band, done: true).map { |row| row[:band_card] }).to eq([newer, older])
  end

  it "only looks in the band's own collection when it has one" do
    band.update!(collection: binder)
    both = card('Both')
    hold(both, binder)
    hold(both, trade_box)
    create(:price_band_card, :to_do, band: band, magic_card: both)

    expect(described_class.call(band: band).sole[:places]).to eq([{ name: 'Binder', copies: 1 }])
  end
end
