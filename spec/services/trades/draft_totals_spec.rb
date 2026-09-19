require 'rails_helper'

RSpec.describe Trades::DraftTotals, type: :service do
  let(:proposer) { create(:user, username: 'proposer', trades_public: true) }
  let(:recipient) { create(:user, username: 'recipient', trades_public: true) }
  let(:lotus) do
    create(:magic_card, name: 'Black Lotus', normal_price: 10, foil_price: 30,
                        ck_buylist_normal_price: 6, ck_buylist_foil_price: 20)
  end
  let(:bolt) { create(:magic_card, name: 'Lightning Bolt', normal_price: 2, foil_price: 5) }

  def binder_row(user, magic_card, public: true)
    collection = create(:collection, user: user, is_public: public)
    create(:collection_magic_card, collection: collection, magic_card: magic_card,
                                   quantity: 4, foil_quantity: 2, trade_quantity: 4,
                                   trade_foil_quantity: 2)
  end

  def item(row, side, quantity: 1, foil_quantity: 0)
    { collection_magic_card_id: row.id, side: side, quantity: quantity, foil_quantity: foil_quantity }
  end

  def totals(items)
    described_class.call(proposer: proposer, recipient: recipient, items: items)
  end

  it "prices each side at today's retail and buylist" do
    result = totals([item(binder_row(proposer, lotus), 'proposer', quantity: 2, foil_quantity: 1)])

    expect(result[:proposer]).to include(copies: 3, retail: 50, buylist: 32)
  end

  it 'reads the difference as the recipient side minus the proposer side' do
    result = totals([item(binder_row(proposer, bolt), 'proposer'),
                     item(binder_row(recipient, lotus), 'recipient')])

    expect(result[:difference]).to eq(8)
  end

  it 'totals an empty draft as zero on both sides' do
    result = totals([])

    expect(result).to include(difference: 0)
    expect(result[:proposer]).to include(copies: 0, retail: 0)
  end

  it 'ignores a row the side does not own' do
    mine = binder_row(proposer, lotus)

    expect(totals([item(mine, 'recipient')])[:recipient]).to include(copies: 0, retail: 0)
  end

  it "ignores a row that is not on its owner's public trade list" do
    hidden = binder_row(proposer, lotus, public: false)

    expect(totals([item(hidden, 'proposer')])[:proposer]).to include(copies: 0, retail: 0)
  end
end
