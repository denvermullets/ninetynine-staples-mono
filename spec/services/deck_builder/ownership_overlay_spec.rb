require 'rails_helper'

RSpec.describe DeckBuilder::OwnershipOverlay, type: :service do
  let(:user) { create(:user) }
  let(:binder) { create(:collection, user: user, name: 'Binder') }
  let(:deck) { create(:collection, user: user, collection_type: 'commander_deck') }
  let(:card) { create(:magic_card, scryfall_oracle_id: SecureRandom.uuid) }
  let(:oracle_ids) { [card.scryfall_oracle_id] }

  def overlay(**)
    described_class.call(user: user, oracle_ids: oracle_ids, **)
  end

  it 'returns nothing without a user' do
    create(:collection_magic_card, collection: binder, magic_card: card, quantity: 1)

    expect(described_class.call(user: nil, oracle_ids: oracle_ids)).to eq({})
  end

  it 'reports the collection holding a card and how many are free' do
    create(:collection_magic_card, collection: binder, magic_card: card, quantity: 3)

    entry = overlay[card.scryfall_oracle_id].first
    expect(entry).to include(collection_name: 'Binder', available: 3, card_type: :regular,
                             type_label: 'Regular', magic_card_id: card.id)
  end

  it 'returns one entry per finish' do
    create(:collection_magic_card, collection: binder, magic_card: card, quantity: 2, foil_quantity: 1)

    expect(overlay[card.scryfall_oracle_id].map { |e| [e[:card_type], e[:available]] })
      .to contain_exactly([:regular, 2], [:foil, 1])
  end

  it 'skips finishes with nothing available' do
    create(:collection_magic_card, collection: binder, magic_card: card, quantity: 0, foil_quantity: 2)

    expect(overlay[card.scryfall_oracle_id].pluck(:card_type)).to eq([:foil])
  end

  it 'excludes the deck being built' do
    create(:collection_magic_card, collection: deck, magic_card: card, quantity: 1)

    expect(overlay(exclude_collection_id: deck.id)).to eq({})
  end

  it 'ignores staged and needed rows' do
    create(:collection_magic_card, collection: binder, magic_card: card, quantity: 1, needed: true)

    expect(overlay).to eq({})
  end

  # Copies already promised to another deck are not copies you can add to this one.
  it 'subtracts copies staged out of the source collection' do
    create(:collection_magic_card, collection: binder, magic_card: card, quantity: 3)
    create(:collection_magic_card, collection: deck, magic_card: card, staged: true,
                                   source_collection_id: binder.id, staged_quantity: 2)

    expect(overlay(exclude_collection_id: deck.id)[card.scryfall_oracle_id].first[:available]).to eq(1)
  end

  # The batched path has to produce the same numbers as the per-row one it replaced, or ownership counts
  # silently drift between the two callers.
  it 'matches calculate_available for every row in one query' do
    rows = Array.new(3) do
      other = create(:magic_card, scryfall_oracle_id: SecureRandom.uuid)
      create(:collection_magic_card, collection: binder, magic_card: other, quantity: 2, foil_quantity: 1)
    end

    batched = DeckBuilder::StagedQuantities.calculate_available_batch(sources: rows)
    rows.each do |row|
      expect(batched[row.id]).to eq(DeckBuilder::StagedQuantities.calculate_available(source: row))
    end
  end
end
