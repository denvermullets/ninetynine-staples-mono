require 'rails_helper'

RSpec.describe CardAnalysis::PreconInclusion, type: :service do
  let(:white) { Color.find_or_create_by!(name: 'W') }
  let(:blue) { Color.find_or_create_by!(name: 'U') }

  def card(name:, colors: [], is_token: false)
    magic_card = create(:magic_card, name: name, scryfall_oracle_id: SecureRandom.uuid,
                                     card_side: nil, is_token: is_token)
    colors.each { |color| MagicCardColorIdent.create!(magic_card: magic_card, color: color) }
    magic_card
  end

  # A precon: its commander sets the deck identity, the rest is the main board.
  def precon(commander:, cards: [], deck_type: 'Commander Deck')
    deck = create(:precon_deck, deck_type: deck_type)
    PreconDeckCard.create!(precon_deck: deck, magic_card: commander, board_type: 'commander')
    cards.each { |c| PreconDeckCard.create!(precon_deck: deck, magic_card: c, board_type: 'mainBoard') }
    deck
  end

  def stats_for(*magic_cards)
    described_class.call(oracle_ids: magic_cards.map { |c| c.scryfall_oracle_id.to_s })
  end

  let(:mono_white_commander) { card(name: 'White Commander', colors: [white]) }
  let(:rock) { card(name: 'Arcane Signet') }

  it 'counts the precons a card appears in' do
    3.times { precon(commander: mono_white_commander, cards: [rock]) }

    expect(stats_for(rock).dig(rock.scryfall_oracle_id.to_s, :deck_count)).to eq(3)
  end

  it 'counts a card on the commander board as an appearance' do
    precon(commander: mono_white_commander)

    expect(stats_for(mono_white_commander).dig(mono_white_commander.scryfall_oracle_id.to_s, :deck_count)).to eq(1)
  end

  it 'omits a card that appears in no precon' do
    precon(commander: mono_white_commander)
    absent = card(name: 'Turtle Blimp')

    expect(stats_for(absent)).to be_empty
  end

  # precon_deck_cards points at a printing, but "is this card in precons" is a question about the
  # card, so two printings of the same card in one deck are one appearance.
  it 'counts a card once per deck no matter how many printings of it are in there' do
    deck = precon(commander: mono_white_commander)
    reprint = create(:magic_card, name: 'Arcane Signet', card_side: nil,
                                  scryfall_oracle_id: rock.scryfall_oracle_id)
    PreconDeckCard.create!(precon_deck: deck, magic_card: rock, board_type: 'mainBoard')
    PreconDeckCard.create!(precon_deck: deck, magic_card: reprint, board_type: 'mainBoard')

    expect(stats_for(rock).dig(rock.scryfall_oracle_id.to_s, :deck_count)).to eq(1)
  end

  # PreconDeck.deck_type has 30+ values and most of them are not Commander. A Jumpstart pack or a
  # Theme Deck would poison a Commander prior if it were pulled in wholesale.
  it 'ignores decks that are not Commander precons' do
    precon(commander: mono_white_commander, cards: [rock], deck_type: 'Theme Deck')

    expect(stats_for(rock)).to be_empty
  end

  it 'ignores tokens' do
    token = card(name: 'Treasure', is_token: true)
    precon(commander: mono_white_commander, cards: [token])

    expect(stats_for(token)).to be_empty
  end

  describe 'eligibility' do
    # The load-bearing correction. A white card can only appear in decks that play white; a colourless
    # one can appear in every deck. Counting raw appearances would rank the colourless card higher for
    # no reason other than how many decks were legally able to run it.
    it 'counts only the decks that could legally run the card' do
      mono_blue_commander = card(name: 'Blue Commander', colors: [blue])
      white_card = card(name: 'Swords to Plowshares', colors: [white])

      2.times { precon(commander: mono_white_commander, cards: [white_card]) }
      2.times { precon(commander: mono_blue_commander, cards: [rock]) }

      stats = stats_for(white_card, rock)

      expect(stats.dig(white_card.scryfall_oracle_id.to_s, :eligible)).to eq(2)
      expect(stats.dig(rock.scryfall_oracle_id.to_s, :eligible)).to eq(4)
    end

    it 'rates a card in every deck it could play in above one that skipped most of its own' do
      mono_blue_commander = card(name: 'Blue Commander', colors: [blue])
      white_card = card(name: 'Swords to Plowshares', colors: [white])

      2.times { precon(commander: mono_white_commander, cards: [white_card]) }
      6.times { precon(commander: mono_blue_commander) }
      2.times { precon(commander: mono_blue_commander, cards: [rock]) }

      stats = stats_for(white_card, rock)

      # Both appear twice; the white card did so out of two chances and the rock out of ten.
      expect(stats.dig(white_card.scryfall_oracle_id.to_s, :deck_count))
        .to eq(stats.dig(rock.scryfall_oracle_id.to_s, :deck_count))
      expect(stats.dig(white_card.scryfall_oracle_id.to_s, :rate))
        .to be > stats.dig(rock.scryfall_oracle_id.to_s, :rate)
    end

    it 'treats a deck identity as the union of its partner commanders' do
      deck = create(:precon_deck, deck_type: 'Commander Deck')
      PreconDeckCard.create!(precon_deck: deck, magic_card: mono_white_commander, board_type: 'commander')
      PreconDeckCard.create!(precon_deck: deck, magic_card: card(name: 'Blue Partner', colors: [blue]),
                             board_type: 'commander')
      wu_card = card(name: 'Azorius Thing', colors: [white, blue])
      PreconDeckCard.create!(precon_deck: deck, magic_card: wu_card, board_type: 'mainBoard')

      expect(stats_for(wu_card).dig(wu_card.scryfall_oracle_id.to_s, :eligible)).to eq(1)
    end
  end

  it 'returns nothing when asked about nothing' do
    expect(described_class.call(oracle_ids: [])).to eq({})
  end
end
