require 'rails_helper'

RSpec.describe Trades::WantDraft, type: :service do
  let(:proposer) { create(:user, username: 'proposer', trades_public: true) }
  let(:recipient) { create(:user, username: 'recipient', trades_public: true) }
  let(:oracle_id) { SecureRandom.uuid }
  let(:lotus) { create(:magic_card, name: 'Black Lotus', scryfall_oracle_id: oracle_id) }
  let(:reprint) { create(:magic_card, name: 'Black Lotus', scryfall_oracle_id: oracle_id, boxset: create(:boxset)) }
  let(:bolt) { create(:magic_card, name: 'Lightning Bolt') }

  def binder_row(magic_card, **counts)
    collection = create(:collection, user: recipient, is_public: true)
    create(:collection_magic_card, { collection: collection, magic_card: magic_card, quantity: 4,
                                     foil_quantity: 2, trade_quantity: 4, trade_foil_quantity: 2 }.merge(counts))
  end

  def want(magic_card, *traits, **attributes)
    create(:want_list_item, *traits, { user: proposer, magic_card: magic_card }.merge(attributes))
  end

  # the builder's "they give" column, as trades#new builds it
  def draft(*wants, want_ids: wants.map(&:id))
    described_class.call(proposer: proposer, want_ids: want_ids, rows: Trades::AvailableRows.call(user: recipient))
  end

  it 'starts the row meeting a want at the copies the want asks for' do
    row = binder_row(lotus)

    expect(draft(want(lotus, quantity: 2))).to eq(row.id => { quantity: 2, foil_quantity: 0 })
  end

  it 'meets an any-printing want with another printing' do
    row = binder_row(reprint)

    expect(draft(want(lotus))).to eq(row.id => { quantity: 1, foil_quantity: 0 })
  end

  it 'leaves another printing alone for a want on this printing only' do
    binder_row(reprint)

    expect(draft(want(lotus, :specific_printing))).to be_empty
  end

  it 'takes only foils for a foil want and only regular copies for a non-foil one' do
    foil_row = binder_row(lotus)
    regular_row = binder_row(bolt)

    expect(draft(want(lotus, foil_preference: 'foil'), want(bolt, foil_preference: 'non_foil', quantity: 2)))
      .to eq(foil_row.id => { quantity: 0, foil_quantity: 1 }, regular_row.id => { quantity: 2, foil_quantity: 0 })
  end

  it 'moves on to foils once the regular copies run out' do
    row = binder_row(lotus, trade_quantity: 1)

    expect(draft(want(lotus, quantity: 2))).to eq(row.id => { quantity: 1, foil_quantity: 1 })
  end

  it 'only takes copies that are on the trade list, however many more the row holds' do
    row = binder_row(lotus, trade_quantity: 1, trade_foil_quantity: 0)

    expect(draft(want(lotus, quantity: 3))).to eq(row.id => { quantity: 1, foil_quantity: 0 })
  end

  it 'caps a want at what the row has left to offer' do
    row = binder_row(lotus, trade_quantity: 1, trade_foil_quantity: 0)

    expect(draft(want(lotus, quantity: 3))).to eq(row.id => { quantity: 1, foil_quantity: 0 })
  end

  it 'does not hand the same copy to two wants' do
    row = binder_row(lotus, trade_quantity: 1, trade_foil_quantity: 0)

    expect(draft(want(lotus, :specific_printing), want(reprint))).to eq(row.id => { quantity: 1, foil_quantity: 0 })
  end

  # "Propose for every match" on the matches page. trades#new puts the unmarked rows on the page with
  # `also` first, so there is something for the draft to reach past the trade list into.
  describe 'with unlisted copies included' do
    def full_draft(*wants)
      rows = Trades::AvailableRows.call(user: recipient, also: recipient.collection_magic_cards.ids)

      described_class.call(proposer: proposer, want_ids: wants.map(&:id), rows: rows, include_unlisted: true)
    end

    it 'takes copies the holder never marked for trade' do
      row = binder_row(lotus, trade_quantity: 0, trade_foil_quantity: 0)

      expect(full_draft(want(lotus, quantity: 2))).to eq(row.id => { quantity: 2, foil_quantity: 0 })
    end

    it 'reaches past the trade list on a row that is only part listed' do
      row = binder_row(lotus, quantity: 4, foil_quantity: 0, trade_quantity: 1, trade_foil_quantity: 0)

      expect(full_draft(want(lotus, quantity: 3))).to eq(row.id => { quantity: 3, foil_quantity: 0 })
    end

    it 'still caps a want at the copies the holder owns' do
      row = binder_row(lotus, quantity: 1, foil_quantity: 0, trade_quantity: 0, trade_foil_quantity: 0)

      expect(full_draft(want(lotus, quantity: 3))).to eq(row.id => { quantity: 1, foil_quantity: 0 })
    end
  end

  # the ids ride in the query string: somebody else's, a removed one and one with no copies left are
  # all just ignored
  describe 'ids that are no longer available' do
    it 'ignores a want that belongs to somebody else' do
      binder_row(lotus)
      theirs = create(:want_list_item, user: recipient, magic_card: lotus)

      expect(draft(want_ids: [theirs.id])).to be_empty
    end

    it 'ignores a want that has been removed' do
      binder_row(lotus)
      removed = want(lotus)
      removed.destroy!

      expect(draft(want_ids: [removed.id])).to be_empty
    end

    it 'ignores a want nothing on offer meets any more' do
      binder_row(lotus, trade_quantity: 0, trade_foil_quantity: 0)
      row = binder_row(bolt)

      expect(draft(want(lotus), want(bolt))).to eq(row.id => { quantity: 1, foil_quantity: 0 })
    end
  end

  it 'is empty without any ids' do
    binder_row(lotus)

    expect(draft(want_ids: [])).to be_empty
  end
end
