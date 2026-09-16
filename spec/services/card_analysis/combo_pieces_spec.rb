require 'rails_helper'

RSpec.describe CardAnalysis::ComboPieces, type: :service do
  let(:deck) { create(:collection, collection_type: 'commander_deck') }
  let(:piece) { SecureRandom.uuid }

  def combo_missing(*oracle_ids, results: 'Infinite mana', combo_type: 'almost_included', banned: false, on: deck)
    combo = Combo.create!(spellbook_id: SecureRandom.hex(4), results: results, has_banned_card: banned)
    deck_combo = DeckCombo.create!(collection: on, combo: combo, combo_type: combo_type)
    oracle_ids.each do |oracle_id|
      deck_combo.deck_combo_missing_cards.create!(card_name: 'Missing Piece', oracle_id: oracle_id)
    end
    deck_combo
  end

  def pieces(**)
    described_class.call(deck: deck, **)
  end

  it 'counts every combo a single missing card would complete' do
    combo_missing(piece, results: 'Infinite mana')
    combo_missing(piece, results: 'Infinite tokens')

    expect(pieces[piece]).to eq({ combo_count: 2, combo_results: ['Infinite mana', 'Infinite tokens'] })
  end

  it 'ignores combos missing more than one card' do
    combo_missing(piece, SecureRandom.uuid)

    expect(pieces).to be_empty
  end

  it 'ignores combos the deck already has' do
    combo_missing(piece, combo_type: 'included')

    expect(pieces).to be_empty
  end

  it 'ignores combos with a banned card' do
    combo_missing(piece, banned: true)

    expect(pieces).to be_empty
  end

  it 'ignores excluded cards' do
    combo_missing(piece)

    expect(pieces(exclude_oracle_ids: [piece])).to be_empty
  end

  it 'ignores combos from other decks' do
    combo_missing(piece, on: create(:collection, collection_type: 'commander_deck'))

    expect(pieces).to be_empty
  end
end
