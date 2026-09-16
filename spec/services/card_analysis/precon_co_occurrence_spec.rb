require 'rails_helper'

RSpec.describe CardAnalysis::PreconCoOccurrence, type: :service do
  def card(name)
    create(:magic_card, name: name, scryfall_oracle_id: SecureRandom.uuid, card_side: nil)
  end

  def precon(cards, deck_type: 'Commander Deck')
    deck = create(:precon_deck, deck_type: deck_type)
    cards.each { |c| PreconDeckCard.create!(precon_deck: deck, magic_card: c, board_type: 'mainBoard') }
    deck
  end

  def oracle(magic_card) = magic_card.scryfall_oracle_id.to_s

  def lift_for(result, magic_card) = result.dig(oracle(magic_card), :lift)

  let(:dragon_a) { card('Atarka, World Render') }
  let(:dragon_b) { card('Bogardan Hellkite') }
  let(:dragon_c) { card('Territorial Hellkite') }
  let(:sol_ring) { card('Sol Ring') }
  let(:command_tower) { card('Command Tower') }
  let(:unrelated) { card('Counterspell') }

  # Three dragon decks and three that run no dragons at all, with Sol Ring and Command Tower in every
  # one of them. Anchoring on a dragon should surface the other dragons and say nothing special about
  # the two cards that are simply in everything.
  def build_corpus
    3.times { precon([dragon_a, dragon_b, dragon_c, sol_ring, command_tower]) }
    3.times { precon([unrelated, sol_ring, command_tower]) }
  end

  it 'returns nothing without anchors' do
    build_corpus

    expect(described_class.call(anchor_oracle_ids: [])).to eq({})
  end

  it 'lifts the cards that travel with the anchor' do
    build_corpus
    result = described_class.call(anchor_oracle_ids: [oracle(dragon_a)])

    expect(lift_for(result, dragon_b)).to be > 1.0
  end

  it 'omits a card that never shares a precon with the anchor' do
    build_corpus
    result = described_class.call(anchor_oracle_ids: [oracle(dragon_a)])

    expect(result).not_to include(oracle(unrelated))
  end

  # The card in every deck is in every deck. It is not evidence of anything about this one.
  it 'does not lift a card that is equally common everywhere' do
    build_corpus
    result = described_class.call(anchor_oracle_ids: [oracle(dragon_a)])

    expect(lift_for(result, dragon_b)).to be > lift_for(result, sol_ring)
  end

  it 'excludes the anchors themselves from the result' do
    build_corpus
    result = described_class.call(anchor_oracle_ids: [oracle(dragon_a), oracle(sol_ring)])

    expect(result).not_to include(oracle(dragon_a), oracle(sol_ring))
  end

  it 'reports how many precons the candidate appears in as support' do
    build_corpus
    result = described_class.call(anchor_oracle_ids: [oracle(dragon_a)])

    expect(result.dig(oracle(dragon_b), :support)).to eq(3)
  end

  it 'ignores decks that are not Commander precons' do
    3.times { precon([dragon_a, dragon_b], deck_type: 'Theme Deck') }

    expect(described_class.call(anchor_oracle_ids: [oracle(dragon_a)])).to be_empty
  end

  # The failure this class exists to avoid, and the reason it is measured pairwise. At deck level -
  # "precons sharing any anchor" - an anchor set this broad matches every deck in the corpus, so
  # P(card | anchors) equals P(card) and every lift collapses to exactly 1.0. Averaging the
  # per-anchor conditionals keeps the dragons ahead of the card that is simply in everything.
  it 'still separates cards when the anchor set spans the whole corpus' do
    build_corpus
    # Every deck in the corpus contains one of these, so a deck-level measurement has nothing left to
    # compare against and hands back 1.0 for everything.
    anchors = [oracle(dragon_a), oracle(dragon_c), oracle(sol_ring)]
    result = described_class.call(anchor_oracle_ids: anchors)

    expect(lift_for(result, dragon_b)).to be > lift_for(result, command_tower)
    expect(lift_for(result, dragon_b)).to be > 1.0
  end

  it 'says nothing when the anchors have no precon in common with anything' do
    build_corpus
    stranger = card('Some Card In No Precon')

    expect(described_class.call(anchor_oracle_ids: [oracle(stranger)])).to be_empty
  end
end
