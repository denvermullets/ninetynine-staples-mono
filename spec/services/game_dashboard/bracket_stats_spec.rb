require 'rails_helper'

RSpec.describe GameDashboard::BracketStats, type: :service do
  let(:user) { create(:user) }
  let(:tracked_deck) { create(:tracked_deck, user: user) }

  subject { described_class.call(user: user) }

  context 'with no games' do
    it 'returns stats for all 5 brackets' do
      result = subject
      expect(result.size).to eq(5)
      result.each do |stat|
        expect(stat[:total_games]).to eq(0)
        expect(stat[:win_rate]).to eq(0.0)
      end
    end
  end

  context 'with games at bracket 3' do
    before do
      create(:commander_game, user: user, tracked_deck: tracked_deck, won: true, bracket_level: 3)
      create(:commander_game, user: user, tracked_deck: tracked_deck, won: false, bracket_level: 3)
      create(:commander_game, user: user, tracked_deck: tracked_deck, won: true, bracket_level: 3)
    end

    it 'calculates bracket 3 stats' do
      bracket_three = subject.find { |s| s[:bracket] == 3 }
      expect(bracket_three[:total_games]).to eq(3)
      expect(bracket_three[:wins]).to eq(2)
      expect(bracket_three[:losses]).to eq(1)
      expect(bracket_three[:win_rate]).to eq(66.7)
    end

    it 'has zero games for other brackets' do
      bracket_one = subject.find { |s| s[:bracket] == 1 }
      expect(bracket_one[:total_games]).to eq(0)
    end
  end
end
