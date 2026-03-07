require 'rails_helper'

RSpec.describe GameDashboard::OverallStats, type: :service do
  let(:user) { create(:user) }
  let(:tracked_deck) { create(:tracked_deck, user: user) }

  subject { described_class.call(user: user) }

  context 'with no games' do
    it 'returns zero stats' do
      result = subject
      expect(result[:total_games]).to eq(0)
      expect(result[:total_wins]).to eq(0)
      expect(result[:win_rate]).to eq(0.0)
    end
  end

  context 'with games played' do
    before do
      create(:commander_game, user: user, tracked_deck: tracked_deck, won: true,
                              fun_rating: 8, performance_rating: 7, played_on: Date.current)
      create(:commander_game, user: user, tracked_deck: tracked_deck, won: false,
                              fun_rating: 6, performance_rating: 5, played_on: Date.current)
      create(:commander_game, user: user, tracked_deck: tracked_deck, won: true,
                              fun_rating: 9, performance_rating: 8, played_on: 2.months.ago)
    end

    it 'calculates total games' do
      expect(subject[:total_games]).to eq(3)
    end

    it 'calculates wins and losses' do
      expect(subject[:total_wins]).to eq(2)
      expect(subject[:total_losses]).to eq(1)
    end

    it 'calculates win rate' do
      expect(subject[:win_rate]).to eq(66.7)
    end

    it 'calculates average ratings' do
      expect(subject[:avg_fun_rating]).to be_a(BigDecimal)
      expect(subject[:avg_performance_rating]).to be_a(BigDecimal)
    end

    it 'counts games this month' do
      expect(subject[:games_this_month]).to eq(2)
    end

    it 'counts games this year' do
      expect(subject[:games_this_year]).to eq(3)
    end

    it 'counts decks' do
      expect(subject[:total_decks]).to eq(1)
      expect(subject[:active_decks]).to eq(1)
    end
  end
end
