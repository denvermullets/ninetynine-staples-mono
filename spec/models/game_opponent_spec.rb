require 'rails_helper'

RSpec.describe GameOpponent, type: :model do
  describe 'validations' do
    describe 'win_condition' do
      it 'allows blank' do
        opponent = build(:game_opponent, win_condition: '')
        expect(opponent).to be_valid
      end

      it 'accepts valid win conditions' do
        CommanderGame::WIN_CONDITIONS.each do |condition|
          opponent = build(:game_opponent, win_condition: condition)
          expect(opponent).to be_valid
        end
      end

      it 'rejects invalid win conditions' do
        opponent = build(:game_opponent, win_condition: 'Cheating')
        expect(opponent).not_to be_valid
      end
    end
  end

  describe 'scopes' do
    let(:game) { create(:commander_game) }
    let!(:winner) { create(:game_opponent, commander_game: game, won: true) }
    let!(:loser) { create(:game_opponent, commander_game: game, won: false) }

    describe '.winners' do
      it 'returns only winning opponents' do
        expect(described_class.winners).to contain_exactly(winner)
      end
    end

    describe '.losers' do
      it 'returns only losing opponents' do
        expect(described_class.losers).to contain_exactly(loser)
      end
    end
  end

  describe '#commander_display_name' do
    context 'without a partner commander' do
      it 'returns only the commander name' do
        card = create(:magic_card, name: 'Kenrith')
        opponent = create(:game_opponent, commander: card)
        expect(opponent.commander_display_name).to eq('Kenrith')
      end
    end

    context 'with a partner commander' do
      it 'returns both names separated by a slash' do
        card = create(:magic_card, name: 'Bruse Tarl')
        partner = create(:magic_card, name: 'Kraum')
        opponent = create(:game_opponent, commander: card, partner_commander: partner)
        expect(opponent.commander_display_name).to eq('Bruse Tarl / Kraum')
      end
    end
  end
end
