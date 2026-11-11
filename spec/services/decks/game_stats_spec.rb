require 'rails_helper'

RSpec.describe Decks::GameStats, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'commander_deck') }

  def tracked(collection) = create(:tracked_deck, user: user, collection: collection)

  def game(tracked_deck, **attrs) = create(:commander_game, user: user, tracked_deck: tracked_deck, **attrs)

  it 'combines games from every tracked deck linked to the deck' do
    first = tracked(deck)
    second = tracked(deck)
    game(first, won: true, fun_rating: 8, played_on: Date.new(2026, 1, 1))
    game(first, won: false, fun_rating: 5, played_on: Date.new(2026, 3, 1))
    game(second, won: true, played_on: Date.new(2026, 2, 1))

    stats = described_class.call(collections: [deck])[deck.id]

    expect(stats).to have_attributes(games: 3, wins: 2, win_rate: 67, avg_fun: 6.5,
                                     last_played_on: Date.new(2026, 3, 1))
  end

  it 'leaves out decks with no games and gives no fun rating when none were rated' do
    quiet = create(:collection, user: user, collection_type: 'commander_deck')
    game(tracked(deck), won: false)

    result = described_class.call(collections: [deck, quiet])

    expect(result.keys).to eq([deck.id])
    expect(result[deck.id].avg_fun).to be_nil
  end
end
