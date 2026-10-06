require 'rails_helper'

RSpec.describe RecalculateDeckTotals, type: :job do
  let(:card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0) }

  it 'rebuilds a drifted deck total from the cards it holds' do
    deck = create(:collection, collection_type: 'commander_deck', total_quantity: 101)
    create(:collection_magic_card, collection: deck, magic_card: card, quantity: 100, foil_quantity: 0)

    described_class.perform_now

    expect(deck.reload).to have_attributes(total_quantity: 100, total_value: 500)
  end

  it 'leaves staged and needed cards out of the totals' do
    deck = create(:collection, collection_type: 'deck')
    create(:collection_magic_card, collection: deck, magic_card: card, quantity: 2)
    create(:collection_magic_card, collection: deck, magic_card: create(:magic_card), quantity: 1, needed: true)
    create(:collection_magic_card, collection: deck, magic_card: create(:magic_card), staged: true,
                                   staged_quantity: 1, quantity: 0)

    described_class.perform_now

    expect(deck.reload.total_cards).to eq(2)
  end

  it 'skips collections that are not decks' do
    binder = create(:collection, collection_type: 'binder', total_quantity: 7)

    described_class.perform_now

    expect(binder.reload.total_quantity).to eq(7)
  end
end
