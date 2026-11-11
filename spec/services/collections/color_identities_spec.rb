require 'rails_helper'

RSpec.describe Collections::ColorIdentities, type: :service do
  subject(:identities) { described_class.call(collections: [deck]) }

  let(:deck) { create(:collection, collection_type: 'commander_deck') }

  def color(letter)
    @colors ||= {}
    @colors[letter] ||= Color.find_by(name: letter) || create(:color, name: letter)
  end

  def add(colors:, board_type: 'mainboard', to: deck)
    card = create(:magic_card, scryfall_oracle_id: SecureRandom.uuid)
    colors.each { |letter| MagicCardColorIdent.create!(magic_card: card, color: color(letter)) }
    create(:collection_magic_card, collection: to, magic_card: card, board_type: board_type)
  end

  it "takes the commander's identity over off-colour mainboard cards" do
    add(colors: %w[B R], board_type: 'commander')
    add(colors: %w[G])

    expect(identities[deck.id]).to eq('BR')
  end

  it 'falls back to the union of the mainboard in WUBRG order without a commander' do
    add(colors: %w[G])
    add(colors: %w[W U])

    expect(identities[deck.id]).to eq('WUG')
  end

  it 'leaves the sideboard out' do
    add(colors: %w[R])
    add(colors: %w[U], board_type: 'sideboard')

    expect(identities[deck.id]).to eq('R')
  end

  it 'reports a deck of only colourless cards as C' do
    add(colors: [])

    expect(identities[deck.id]).to eq('C')
  end

  it 'leaves an empty deck out entirely' do
    expect(identities).not_to have_key(deck.id)
  end

  it 'answers for several decks at once' do
    other = create(:collection, collection_type: 'commander_deck', user: deck.user)
    add(colors: %w[W])
    add(colors: %w[B], to: other)

    expect(described_class.call(collections: [deck, other])).to eq(deck.id => 'W', other.id => 'B')
  end
end
