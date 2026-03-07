require 'rails_helper'

RSpec.describe CommanderGame, type: :model do
  describe 'validations' do
    it 'requires played_on' do
      game = build(:commander_game, played_on: nil)
      expect(game).not_to be_valid
      expect(game.errors[:played_on]).to be_present
    end

    describe 'won inclusion' do
      it 'is valid with true' do
        expect(build(:commander_game, won: true)).to be_valid
      end

      it 'is valid with false' do
        expect(build(:commander_game, won: false)).to be_valid
      end
    end

    describe 'pod_size' do
      it 'allows nil' do
        expect(build(:commander_game, pod_size: nil)).to be_valid
      end

      it 'rejects values below 2' do
        expect(build(:commander_game, pod_size: 1)).not_to be_valid
      end

      it 'rejects values above 8' do
        expect(build(:commander_game, pod_size: 9)).not_to be_valid
      end

      it 'accepts values between 2 and 8' do
        expect(build(:commander_game, pod_size: 4)).to be_valid
      end
    end

    describe 'bracket_level' do
      it 'allows nil' do
        expect(build(:commander_game, bracket_level: nil)).to be_valid
      end

      it 'rejects values below 1' do
        expect(build(:commander_game, bracket_level: 0)).not_to be_valid
      end

      it 'rejects values above 5' do
        expect(build(:commander_game, bracket_level: 6)).not_to be_valid
      end
    end

    describe 'fun_rating' do
      it 'allows nil' do
        expect(build(:commander_game, fun_rating: nil)).to be_valid
      end

      it 'rejects values below 1' do
        expect(build(:commander_game, fun_rating: 0)).not_to be_valid
      end

      it 'rejects values above 10' do
        expect(build(:commander_game, fun_rating: 11)).not_to be_valid
      end
    end

    describe 'performance_rating' do
      it 'allows nil' do
        expect(build(:commander_game, performance_rating: nil)).to be_valid
      end

      it 'rejects values below 1' do
        expect(build(:commander_game, performance_rating: 0)).not_to be_valid
      end

      it 'rejects values above 10' do
        expect(build(:commander_game, performance_rating: 11)).not_to be_valid
      end
    end

    describe 'turn_ended_on' do
      it 'allows nil' do
        expect(build(:commander_game, turn_ended_on: nil)).to be_valid
      end

      it 'rejects zero' do
        expect(build(:commander_game, turn_ended_on: 0)).not_to be_valid
      end

      it 'rejects negative values' do
        expect(build(:commander_game, turn_ended_on: -1)).not_to be_valid
      end

      it 'accepts positive values' do
        expect(build(:commander_game, turn_ended_on: 10)).to be_valid
      end
    end

    describe 'win_condition' do
      it 'allows blank' do
        expect(build(:commander_game, win_condition: '')).to be_valid
      end

      it 'accepts valid win conditions' do
        CommanderGame::WIN_CONDITIONS.each do |condition|
          expect(build(:commander_game, win_condition: condition)).to be_valid
        end
      end

      it 'rejects invalid win conditions' do
        expect(build(:commander_game, win_condition: 'Cheating')).not_to be_valid
      end
    end
  end

  describe 'scopes' do
    let(:deck) { create(:tracked_deck) }
    let!(:win) { create(:commander_game, tracked_deck: deck, user: deck.user, won: true) }
    let!(:loss) { create(:commander_game, tracked_deck: deck, user: deck.user, won: false) }

    describe '.wins' do
      it 'returns only wins' do
        expect(described_class.wins).to contain_exactly(win)
      end
    end

    describe '.losses' do
      it 'returns only losses' do
        expect(described_class.losses).to contain_exactly(loss)
      end
    end

    describe '.by_bracket' do
      it 'returns games with the specified bracket level' do
        bracketed = create(:commander_game, tracked_deck: deck, user: deck.user, bracket_level: 3)
        expect(described_class.by_bracket(3)).to contain_exactly(bracketed)
      end
    end

    describe '.recent' do
      it 'returns games ordered by played_on desc' do
        old_game = create(:commander_game, tracked_deck: deck, user: deck.user, played_on: 1.week.ago)
        new_game = create(:commander_game, tracked_deck: deck, user: deck.user, played_on: Date.current)
        result = described_class.recent
        expect(result.index(new_game)).to be < result.index(old_game)
      end
    end

    describe '.by_user' do
      it 'returns games for the given user' do
        other_deck = create(:tracked_deck)
        create(:commander_game, tracked_deck: other_deck, user: other_deck.user)
        expect(described_class.by_user(deck.user.id)).to contain_exactly(win, loss)
      end
    end
  end

  describe '#result_text' do
    it 'returns Win when won is true' do
      expect(build(:commander_game, won: true).result_text).to eq('Win')
    end

    it 'returns Loss when won is false' do
      expect(build(:commander_game, won: false).result_text).to eq('Loss')
    end
  end

  describe '#result_badge_class' do
    it 'returns win class when won' do
      expect(build(:commander_game, won: true).result_badge_class).to eq('bg-accent-50/20 text-accent-50')
    end

    it 'returns loss class when lost' do
      expect(build(:commander_game, won: false).result_badge_class).to eq('bg-accent-100/20 text-accent-100')
    end
  end

  describe '#opponent_count' do
    it 'returns the number of game opponents' do
      game = create(:commander_game)
      create_list(:game_opponent, 3, commander_game: game)
      expect(game.opponent_count).to eq(3)
    end
  end

  describe '#winning_opponent' do
    it 'returns the opponent that won' do
      game = create(:commander_game)
      create(:game_opponent, commander_game: game, won: false)
      winner = create(:game_opponent, commander_game: game, won: true)
      expect(game.winning_opponent).to eq(winner)
    end

    it 'returns nil when no opponent won' do
      game = create(:commander_game)
      create(:game_opponent, commander_game: game, won: false)
      expect(game.winning_opponent).to be_nil
    end
  end

  describe '#deck_name' do
    it 'returns the tracked deck name' do
      deck = create(:tracked_deck, name: 'Eldrazi Ramp')
      game = create(:commander_game, tracked_deck: deck, user: deck.user)
      expect(game.deck_name).to eq('Eldrazi Ramp')
    end
  end
end
