require 'rails_helper'

RSpec.describe GameDashboard::OpponentStats, type: :service do
  let(:user) { create(:user) }
  let(:tracked_deck) { create(:tracked_deck, user: user) }
  let(:opponent_commander) { create(:magic_card, name: 'Enemy Commander') }

  subject { described_class.call(user: user) }

  context 'with no games' do
    it 'returns empty stats' do
      result = subject
      expect(result[:commanders_that_beat_you]).to be_empty
      expect(result[:win_conditions_against_you]).to be_empty
      expect(result[:most_faced_commanders]).to be_empty
    end
  end

  context 'with opponent data' do
    before do
      game = create(:commander_game, user: user, tracked_deck: tracked_deck, won: false)
      create(:game_opponent, commander_game: game, commander: opponent_commander,
                             won: true, win_condition: 'Combat')
    end

    it 'tracks commanders that beat you' do
      result = subject[:commanders_that_beat_you]
      expect(result.first[:commander_name]).to eq('Enemy Commander')
      expect(result.first[:losses]).to eq(1)
    end

    it 'tracks win conditions used against you' do
      result = subject[:win_conditions_against_you]
      expect(result.first[:win_condition]).to eq('Combat')
    end

    it 'tracks most faced commanders' do
      result = subject[:most_faced_commanders]
      expect(result.first[:commander_name]).to eq('Enemy Commander')
      expect(result.first[:games]).to eq(1)
    end
  end
end
