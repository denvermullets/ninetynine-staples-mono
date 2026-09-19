require 'rails_helper'

RSpec.describe WantList::Matches, type: :service do
  let(:user) { create(:user, username: 'wanter') }
  let(:holder) { create(:user, username: 'holder', trades_public: true) }
  let(:binder) { create(:collection, user: holder) }
  let(:oracle_id) { SecureRandom.uuid }
  let(:card) { create(:magic_card, name: 'Mox Diamond', scryfall_oracle_id: oracle_id) }
  let(:other_printing) do
    create(:magic_card, name: 'Mox Diamond', scryfall_oracle_id: oracle_id, boxset: create(:boxset))
  end

  def matches(**)
    described_class.call(user: user, **)[:users]
  end

  def hold(magic_card, *traits, collection: binder, **)
    create(:collection_magic_card, *traits, collection: collection, magic_card: magic_card, **)
  end

  it 'rejects a direction it does not know' do
    expect { described_class.call(user: user, direction: :sideways) }.to raise_error(ArgumentError)
  end

  it 'is empty without a user' do
    expect(described_class.call(user: nil)).to eq(users: [], total: 0)
  end

  describe 'the match rule' do
    it 'matches the wanted printing' do
      want = create(:want_list_item, user: user, magic_card: card)
      hold(card, quantity: 2, foil_quantity: 1)

      result = matches.first

      expect(result).to have_attributes(user: holder, tradeable_count: 0, total_count: 1)
      expect(result.matches.first).to have_attributes(want: want, printing: card, tradeable: false,
                                                      quantity: 2, foil_quantity: 1)
    end

    it 'matches another printing for an any-printing want' do
      create(:want_list_item, user: user, magic_card: card)
      hold(other_printing)

      expect(matches.first.matches.map(&:printing)).to eq([other_printing])
    end

    it 'counts an any-printing want once however many printings meet it' do
      create(:want_list_item, user: user, magic_card: card)
      hold(card)
      hold(other_printing)

      expect(matches.first).to have_attributes(total_count: 1)
      expect(matches.first.matches.map(&:printing)).to contain_exactly(card, other_printing)
    end

    it 'ignores another printing for a specific want' do
      create(:want_list_item, :specific_printing, user: user, magic_card: card)
      hold(other_printing)

      expect(matches).to be_empty
    end

    it 'matches a printing with no oracle id exactly, whatever any_printing says' do
      orphan = create(:magic_card, scryfall_oracle_id: nil)
      create(:want_list_item, user: user, magic_card: orphan)
      hold(orphan)
      hold(create(:magic_card, scryfall_oracle_id: nil))

      expect(matches.first.matches.map(&:printing)).to eq([orphan])
    end

    it 'does not match on the back face of another card' do
      create(:want_list_item, user: user, magic_card: card)
      hold(create(:magic_card, scryfall_oracle_id: oracle_id, card_side: 'b'))

      expect(matches).to be_empty
    end

    it 'sums a printing across the holder\'s public collections' do
      create(:want_list_item, user: user, magic_card: card)
      hold(card, quantity: 1)
      hold(card, collection: create(:collection, user: holder), quantity: 2)

      expect(matches.first.matches.first).to have_attributes(quantity: 3)
    end
  end

  describe 'foil preference' do
    it 'needs a foil copy for a foil want' do
      create(:want_list_item, :foil, user: user, magic_card: card)
      hold(card, quantity: 3, foil_quantity: 0)

      expect(matches).to be_empty
    end

    it 'reports only the foil copies for a foil want' do
      create(:want_list_item, :foil, user: user, magic_card: card)
      hold(card, quantity: 3, foil_quantity: 1)

      expect(matches.first.matches.first).to have_attributes(quantity: 0, foil_quantity: 1)
    end

    it 'needs a regular copy for a non-foil want' do
      create(:want_list_item, user: user, magic_card: card, foil_preference: 'non_foil')
      hold(card, quantity: 0, foil_quantity: 2)

      expect(matches).to be_empty
    end

    it 'takes either finish for an any want' do
      create(:want_list_item, user: user, magic_card: card)
      hold(card, quantity: 0, foil_quantity: 2)

      expect(matches.first.matches.first).to have_attributes(quantity: 0, foil_quantity: 2)
    end

    it 'does not call a foil want tradeable over a marked regular copy' do
      create(:want_list_item, :foil, user: user, magic_card: card)
      hold(card, quantity: 1, foil_quantity: 1, trade_quantity: 1)

      expect(matches.first.matches.first).to have_attributes(tradeable: false, trade_quantity: 0)
    end
  end

  describe 'rows that are not copies' do
    before { create(:want_list_item, user: user, magic_card: card) }

    it 'leaves out staged and needed rows' do
      hold(card, staged: true)
      hold(card, needed: true)

      expect(matches).to be_empty
    end

    it 'leaves out proxy-only rows' do
      hold(card, quantity: 0, foil_quantity: 0, proxy_quantity: 2, proxy_foil_quantity: 1)

      expect(matches).to be_empty
    end
  end

  describe 'visibility' do
    before { create(:want_list_item, user: user, magic_card: card) }

    it 'hides private collections' do
      hold(card, collection: create(:collection, user: holder, is_public: false))

      expect(matches).to be_empty
    end

    it 'leaves out the user\'s own collections' do
      hold(card, collection: create(:collection, user: user))

      expect(matches).to be_empty
    end

    it 'keeps a holder with a private trade list, without their trade marks' do
      holder.update!(trades_public: false)
      hold(card, :tradeable)

      expect(matches.first).to have_attributes(user: holder, tradeable_count: 0, total_count: 1)
      expect(matches.first.matches.first).to have_attributes(tradeable: false, trade_quantity: 0)
    end
  end

  describe 'ranking' do
    let(:second_card) { create(:magic_card, name: 'Ancient Tomb', scryfall_oracle_id: SecureRandom.uuid) }

    before do
      create(:want_list_item, user: user, magic_card: card)
      create(:want_list_item, user: user, magic_card: second_card)
    end

    def binder_for(username, **)
      create(:collection, user: create(:user, username: username, trades_public: true, **))
    end

    it 'puts a holder with a tradeable copy ahead of one who matches more wants' do
      hoarder = binder_for('hoarder')
      hold(card, collection: hoarder)
      hold(second_card, collection: hoarder)
      hold(card, :tradeable)

      expect(matches.map { |row| row.user.username }).to eq(%w[holder hoarder])
      expect(matches.first).to have_attributes(tradeable_count: 1, total_count: 1)
    end

    it 'then ranks by wants matched, then username' do
      hold(card, collection: binder_for('zed'))
      hold(card, collection: binder_for('abe'))
      both = binder_for('mid')
      hold(card, collection: both)
      hold(second_card, collection: both)

      expect(matches.map { |row| row.user.username }).to eq(%w[mid abe zed])
    end

    it 'lists tradeable matches first inside a holder' do
      hold(second_card)
      hold(card, :tradeable)

      expect(matches.first.matches.map(&:printing)).to eq([card, second_card])
    end

    it 'pages by user and reports how many users matched' do
      hold(card, collection: binder_for('abe'))
      hold(card, collection: binder_for('zed'))

      result = described_class.call(user: user, page: 2, per_page: 1)

      expect(result[:total]).to eq(2)
      expect(result[:users].map { |row| row.user.username }).to eq(%w[zed])
    end

    it 'narrows to one counterpart' do
      hold(card, collection: binder_for('abe'))
      hold(card)

      expect(matches(with: holder).map(&:user)).to eq([holder])
    end
  end

  describe 'copies held by a trade' do
    let(:row) { hold(card, :tradeable, quantity: 2) }

    def commit(copy, *traits, **)
      trade = create(:trade, *traits, proposer: holder)
      create(:trade_item, trade: trade, collection_magic_card: copy, magic_card: copy.magic_card, **)
    end

    before { create(:want_list_item, user: user, magic_card: card) }

    it 'calls a match pending once an accepted trade holds every marked copy' do
      commit(row, :accepted, quantity: 2)

      expect(matches.first).to have_attributes(tradeable_count: 0, total_count: 1)
      expect(matches.first.matches.first).to have_attributes(tradeable: false, pending?: true, quantity: 2,
                                                             trade_quantity: 0, pending_quantity: 2)
    end

    it 'keeps the marked copies a trade has not taken' do
      commit(row, :accepted, quantity: 1)

      expect(matches.first.matches.first).to have_attributes(tradeable: true, pending?: false,
                                                             trade_quantity: 1, pending_quantity: 1)
    end

    it 'stays pending while only one party has confirmed' do
      commit(row, :half_confirmed, quantity: 2)

      expect(matches.first.matches.first).to have_attributes(tradeable: false, pending?: true)
    end

    it 'holds each finish on its own' do
      foils = hold(other_printing, :tradeable, quantity: 1, foil_quantity: 1)
      commit(foils, :accepted, quantity: 0, foil_quantity: 1)

      expect(matches.first.matches.find { |match| match.printing == other_printing })
        .to have_attributes(tradeable: true, trade_quantity: 1, trade_foil_quantity: 0, pending_foil_quantity: 1)
    end

    it 'is not held by a trade that is only proposed' do
      commit(row, quantity: 2)

      expect(matches.first.matches.first).to have_attributes(tradeable: true, pending?: false, trade_quantity: 2)
    end

    it 'is let go by a trade that fell through' do
      commit(row, :accepted, quantity: 2).trade.update!(status: 'cancelled')

      expect(matches.first.matches.first).to have_attributes(tradeable: true, trade_quantity: 2)
    end

    it 'does not call unmarked copies pending' do
      commit(hold(other_printing, quantity: 1), :accepted, quantity: 1)

      expect(matches.first.matches.find { |match| match.printing == other_printing })
        .to have_attributes(tradeable: false, pending?: false)
    end

    it 'says nothing about a private trade list' do
      holder.update!(trades_public: false)
      commit(row, :accepted, quantity: 2)

      expect(matches.first.matches.first).to have_attributes(pending?: false, pending_quantity: 0)
    end

    it 'drops a fully held copy from the inverse direction' do
      user.update!(wants_public: true)
      commit(row, :accepted, quantity: 2)

      expect(described_class.call(user: holder, direction: :inverse)[:users]).to be_empty
    end
  end

  describe 'the inverse direction' do
    let(:fan) { create(:user, username: 'fan', wants_public: true) }

    def wanters(**)
      described_class.call(user: holder, direction: :inverse, **)[:users]
    end

    it 'finds public want lists holding a card marked for trade' do
      want = create(:want_list_item, user: fan, magic_card: card)
      hold(other_printing, :tradeable, quantity: 2)

      expect(wanters.first).to have_attributes(user: fan, tradeable_count: 1, total_count: 1)
      expect(wanters.first.matches.first).to have_attributes(want: want, printing: other_printing,
                                                             tradeable: true, trade_quantity: 2)
    end

    it 'ignores copies that are not marked' do
      create(:want_list_item, user: fan, magic_card: card)
      hold(card)

      expect(wanters).to be_empty
    end

    it 'ignores private want lists' do
      create(:want_list_item, user: create(:user, wants_public: false), magic_card: card)
      hold(card, :tradeable)

      expect(wanters).to be_empty
    end

    it 'honours the foil preference' do
      create(:want_list_item, :foil, user: fan, magic_card: card)
      hold(card, quantity: 1, trade_quantity: 1)

      expect(wanters).to be_empty
    end

    it 'ignores marked copies in a private collection' do
      create(:want_list_item, user: fan, magic_card: card)
      hold(card, :tradeable, collection: create(:collection, user: holder, is_public: false))

      expect(wanters).to be_empty
    end

    it 'still works for a user whose own trade list is private' do
      holder.update!(trades_public: false)
      create(:want_list_item, user: fan, magic_card: card)
      hold(card, :tradeable)

      expect(wanters.map(&:user)).to eq([fan])
    end
  end
end
