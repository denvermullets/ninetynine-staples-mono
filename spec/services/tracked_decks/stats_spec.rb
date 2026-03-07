require 'rails_helper'

RSpec.describe TrackedDecks::Stats, type: :service do
  let(:user) { create(:user) }
  let(:tracked_deck) { create(:tracked_deck, user: user) }

  subject { described_class.call(tracked_deck: tracked_deck) }

  context 'with no games' do
    it 'returns zero stats' do
      result = subject
      expect(result[:total_games]).to eq(0)
      expect(result[:wins]).to eq(0)
      expect(result[:losses]).to eq(0)
      expect(result[:win_rate]).to eq(0.0)
      expect(result[:last_played]).to be_nil
    end
  end

  context 'with games played' do
    before do
      create(:commander_game, user: user, tracked_deck: tracked_deck,
                              won: true, bracket_level: 3, fun_rating: 8,
                              performance_rating: 7, win_condition: 'Combat',
                              turn_ended_on: 10, played_on: Date.current)
      create(:commander_game, user: user, tracked_deck: tracked_deck,
                              won: false, bracket_level: 3, fun_rating: 6,
                              performance_rating: 5, played_on: 1.week.ago)
      create(:commander_game, user: user, tracked_deck: tracked_deck,
                              won: true, bracket_level: 4, fun_rating: 9,
                              performance_rating: 9, win_condition: 'Combo',
                              turn_ended_on: 8, played_on: 2.weeks.ago)
    end

    it 'calculates basic stats' do
      result = subject
      expect(result[:total_games]).to eq(3)
      expect(result[:wins]).to eq(2)
      expect(result[:losses]).to eq(1)
      expect(result[:win_rate]).to eq(66.7)
    end

    it 'calculates average ratings' do
      result = subject
      expect(result[:avg_fun_rating]).to be_present
      expect(result[:avg_performance_rating]).to be_present
    end

    it 'tracks last played date' do
      expect(subject[:last_played]).to eq(Date.current)
    end

    it 'groups games by bracket' do
      result = subject[:games_by_bracket]
      expect(result[3]).to eq(2)
      expect(result[4]).to eq(1)
    end

    it 'calculates win rate by bracket' do
      result = subject[:win_rate_by_bracket]
      expect(result[3]).to eq(50.0)
      expect(result[4]).to eq(100.0)
    end

    it 'finds most common win condition' do
      condition, count = subject[:most_common_win_condition]
      expect(%w[Combat Combo]).to include(condition)
      expect(count).to eq(1)
    end

    it 'calculates average turn ended' do
      expect(subject[:avg_turn_ended]).to eq(9.0)
    end
  end
end
