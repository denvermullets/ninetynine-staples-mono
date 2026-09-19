require 'rails_helper'

RSpec.describe WantList::Traders, type: :service do
  let(:oracle_id) { SecureRandom.uuid }
  let(:bolt) {
    create(:magic_card, name: 'Lightning Bolt', scryfall_oracle_id: oracle_id, normal_price: 2, foil_price: 5)
  }
  let(:reprint) { create(:magic_card, name: 'Lightning Bolt', scryfall_oracle_id: oracle_id, normal_price: 1) }

  let(:user) { create(:user, username: 'wanter') }
  let(:want) { create(:want_list_item, user: user, magic_card: bolt) }
  let(:alice) { trader('alice') }

  def trader(username, **attributes)
    create(:user, username: username, trades_public: true, **attributes)
  end

  def binder(owner, is_public: true)
    create(:collection, user: owner, is_public: is_public)
  end

  def offer(owner, card, quantity: 0, foil_quantity: 0, collection: binder(owner))
    create(:collection_magic_card, collection: collection, magic_card: card,
                                   quantity: quantity, foil_quantity: foil_quantity,
                                   trade_quantity: quantity, trade_foil_quantity: foil_quantity)
  end

  def result(want: self.want, page: 1, per_page: described_class::PER_PAGE)
    found = described_class.call(want: want)
    offers = found[:offers].limit(per_page).offset((page - 1) * per_page)

    found.except(:offers).merge(rows: described_class.present(offers.to_a))
  end

  def listed(**)
    result(**)[:rows].map { |row| [row.user.username, row.printing] }
  end

  it 'lists a trader with the copies they have marked and the asking value' do
    offer(alice, bolt, quantity: 2, foil_quantity: 1)

    row = result[:rows].sole

    expect([row.user, row.printing, row.quantity, row.foil_quantity, row.followed]).to eq([alice, bolt, 2, 1, false])
    expect(row.value).to eq(9.to_d)
  end

  it 'lists every printing for an any-printing want, the wanted one first' do
    offer(alice, reprint, quantity: 5)
    offer(trader('bob'), bolt, quantity: 1)

    expect(listed).to eq([['bob', bolt], ['alice', reprint]])
  end

  it 'keeps a specific-printing want to that printing' do
    specific = create(:want_list_item, :specific_printing, user: user, magic_card: bolt)
    offer(alice, reprint, quantity: 1)
    offer(alice, bolt, quantity: 1)

    expect(listed(want: specific)).to eq([['alice', bolt]])
  end

  it 'puts people the wanter follows first' do
    offer(alice, bolt, quantity: 9)
    zed = trader('zed')
    offer(zed, reprint, quantity: 1)
    create(:follow, follower: user, followed: zed)

    expect(listed).to eq([['zed', reprint], ['alice', bolt]])
    expect(result[:rows].map(&:followed)).to eq([true, false])
  end

  it 'counts only the finish the want asks for' do
    foil_want = create(:want_list_item, :foil, user: user, magic_card: bolt)
    offer(alice, bolt, quantity: 3)
    offer(trader('bob'), bolt, quantity: 3, foil_quantity: 1)

    row = result(want: foil_want)[:rows].sole

    expect([row.user.username, row.quantity, row.foil_quantity]).to eq(['bob', 0, 1])
  end

  it 'sums a trader\'s copies across their public collections' do
    offer(alice, bolt, quantity: 1)
    offer(alice, bolt, quantity: 2)

    expect(result[:rows].sole.quantity).to eq(3)
  end

  it 'leaves out owned copies that are not marked, private trade lists and private collections' do
    create(:collection_magic_card, collection: binder(alice), magic_card: bolt, quantity: 3)
    offer(trader('bob', trades_public: false), bolt, quantity: 1)
    carol = trader('carol')
    offer(carol, bolt, quantity: 1, collection: binder(carol, is_public: false))

    expect(result).to eq(rows: [], total: 0, traders: 0)
  end

  it 'leaves out the wanter\'s own copies' do
    user.update!(trades_public: true)
    offer(user, bolt, quantity: 1)

    expect(result[:rows]).to be_empty
  end

  it 'pages the rows and reports the totals on every page' do
    offer(alice, bolt, quantity: 1)
    offer(alice, reprint, quantity: 1)
    offer(trader('bob'), bolt, quantity: 1)

    page = result(page: 2, per_page: 2)

    expect(page[:rows].map { |row| [row.user.username, row.printing] }).to eq([['alice', reprint]])
    expect(page.slice(:total, :traders)).to eq(total: 3, traders: 2)
  end

  describe '.counts' do
    it 'counts traders per want, and leaves out a want nobody offers' do
      unwanted = create(:want_list_item, user: user, magic_card: create(:magic_card))
      offer(alice, bolt, quantity: 1)
      offer(alice, reprint, quantity: 1)
      offer(trader('bob'), reprint, foil_quantity: 1)

      expect(described_class.counts(wants: [want, unwanted], viewer: user)).to eq(want.id => 2)
    end

    it 'does not count through somebody else\'s want' do
      offer(alice, bolt, quantity: 1)

      expect(described_class.counts(wants: [want], viewer: alice)).to eq({})
    end

    it 'is empty with no wants or no viewer' do
      expect([described_class.counts(wants: [], viewer: user), described_class.counts(wants: [want], viewer: nil)])
        .to eq([{}, {}])
    end
  end
end
