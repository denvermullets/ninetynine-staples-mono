require 'rails_helper'

RSpec.describe GameDashboard::DeckStats, type: :service do
  let(:user) { create(:user) }
  let(:commander) { create(:magic_card, name: 'Test Commander') }
  let(:tracked_deck) { create(:tracked_deck, user: user, commander: commander) }

  subject { described_class.call(user: user) }

  context 'with no decks' do
    it 'returns empty array' do
      expect(subject).to eq([])
    end
  end

  context 'with a deck and games' do
    before do
      create(:commander_game, user: user, tracked_deck: tracked_deck, won: true, fun_rating: 8)
      create(:commander_game, user: user, tracked_deck: tracked_deck, won: false, fun_rating: 6)
    end

    it 'returns deck stats' do
      result = subject
      expect(result.size).to eq(1)

      deck = result.first
      expect(deck[:commander_name]).to eq('Test Commander')
      expect(deck[:games_count]).to eq(2)
      expect(deck[:wins]).to eq(1)
      expect(deck[:losses]).to eq(1)
      expect(deck[:win_rate]).to eq(50.0)
    end
  end

  context 'sorting by games count' do
    let(:commander_b) { create(:magic_card, name: 'Other Commander') }
    let(:deck_b) { create(:tracked_deck, user: user, commander: commander_b, name: 'Deck B') }

    before do
      3.times { create(:commander_game, user: user, tracked_deck: tracked_deck, won: true) }
      create(:commander_game, user: user, tracked_deck: deck_b, won: false)
    end

    it 'sorts decks by games_count DESC' do
      result = subject
      expect(result.first[:games_count]).to be >= result.last[:games_count]
    end
  end
end
