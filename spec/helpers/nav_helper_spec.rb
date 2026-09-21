require 'rails_helper'

RSpec.describe NavHelper, type: :helper do
  let(:user) { create(:user, username: 'staples') }

  # current_user comes from the controller, so the helper under test has to be handed one
  def sign_in_as(someone)
    helper.define_singleton_method(:current_user) { someone }
  end

  before { sign_in_as(user) }

  def section_for(path)
    allow(helper.request).to receive(:path).and_return(path)
    helper.nav_section
  end

  it 'only offers Browse to a visitor' do
    sign_in_as(nil)

    expect(helper.nav_menus.pluck(:key)).to eq(%i[browse])
  end

  it 'gives a signed-in user every menu, trades in one of its own' do
    expect(helper.nav_menus.pluck(:key)).to eq(%i[browse collection decks trades])
  end

  it 'keeps the trade and want lists out of the collection menu' do
    labels = helper.nav_menus.to_h { |menu| [menu[:key], menu[:items].pluck(:label)] }

    expect(labels[:trades]).to include('Trade List', 'Want List', 'Want Matches')
    expect(labels[:collection]).not_to include('Trade List', 'Want List')
  end

  it 'files a trade or want list under trades rather than the collection it lives beneath' do
    expect(section_for('/collections/staples/trades')).to eq(:trades)
    expect(section_for('/collections/staples/wants')).to eq(:trades)
    expect(section_for('/wants/matches')).to eq(:trades)
    expect(section_for('/trades/12')).to eq(:trades)
  end

  it 'files brew under decks' do
    expect(section_for('/collections/staples/brew')).to eq(:decks)
    expect(section_for('/game-tracker/staples')).to eq(:decks)
  end

  it 'offers deck compare in the decks menu and files its page under decks' do
    decks = helper.nav_menus.find { |menu| menu[:key] == :decks }

    expect(decks[:items].pluck(:path)).to include(helper.deck_compare_path)
    expect(section_for('/deck-compare')).to eq(:decks)
  end

  it 'keeps deck compare away from visitors, who cannot open it' do
    sign_in_as(nil)

    expect(helper.nav_menus.flat_map { |menu| menu[:items] }.pluck(:path)).not_to include(helper.deck_compare_path)
  end

  it 'files the rest of the collection under collection' do
    expect(section_for('/collections/staples')).to eq(:collection)
    expect(section_for('/collections/staples/stats')).to eq(:collection)
    expect(section_for('/scan-cards')).to eq(:collection)
  end

  it "leaves someone else's collection unlit" do
    expect(section_for('/collections/somebody')).to be_nil
  end

  it 'lights Browse on the home page' do
    expect(section_for('/')).to eq(:browse)
  end
end
