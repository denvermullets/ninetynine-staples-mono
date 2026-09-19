require 'rails_helper'

RSpec.describe WantList::TradeBadge, type: :service do
  let(:visitor) { create(:user, username: 'visitor') }
  let(:holder) { create(:user, username: 'holder', trades_public: true) }
  let(:binder) { create(:collection, user: holder) }
  let(:oracle_id) { SecureRandom.uuid }
  let(:card) { create(:magic_card, name: 'Mox Diamond', scryfall_oracle_id: oracle_id) }
  let(:other_card) { create(:magic_card, name: 'Gaeas Cradle', scryfall_oracle_id: SecureRandom.uuid) }

  def badge(viewer: visitor)
    described_class.call(viewer: viewer, holder: holder)
  end

  def hold(magic_card, *traits, **)
    create(:collection_magic_card, *traits, collection: binder, magic_card: magic_card, **)
  end

  it 'is zero for a visitor with no wants' do
    hold(card, :tradeable)

    expect(badge).to eq(0)
  end

  it 'is zero for a logged-out visitor' do
    hold(card, :tradeable)

    expect(badge(viewer: nil)).to eq(0)
  end

  it 'is zero for the owner of the list' do
    create(:want_list_item, user: holder, magic_card: card)
    hold(card, :tradeable)

    expect(badge(viewer: holder)).to eq(0)
  end

  it 'counts the wants a marked copy would fill' do
    create(:want_list_item, user: visitor, magic_card: card)
    create(:want_list_item, user: visitor, magic_card: other_card)
    hold(card, :tradeable)
    hold(other_card, :tradeable)

    expect(badge).to eq(2)
  end

  it 'counts a want once however many printings fill it' do
    printing = create(:magic_card, name: 'Mox Diamond', scryfall_oracle_id: oracle_id, boxset: create(:boxset))
    create(:want_list_item, user: visitor, magic_card: card)
    hold(card, :tradeable)
    hold(printing, :tradeable)

    expect(badge).to eq(1)
  end

  it 'leaves out copies the holder owns but has not marked' do
    create(:want_list_item, user: visitor, magic_card: card)
    hold(card)

    expect(badge).to eq(0)
  end

  it 'works from a private want list' do
    visitor.update!(wants_public: false)
    create(:want_list_item, user: visitor, magic_card: card)
    hold(card, :tradeable)

    expect(badge).to eq(1)
  end

  it 'honours the foil preference' do
    create(:want_list_item, :foil, user: visitor, magic_card: card)
    hold(card, quantity: 1, trade_quantity: 1)

    expect(badge).to eq(0)
  end
end
