require 'rails_helper'

RSpec.describe TrackedDeck, type: :model do
  describe 'validations' do
    it 'requires a name' do
      deck = build(:tracked_deck, name: nil)
      expect(deck).not_to be_valid
      expect(deck.errors[:name]).to be_present
    end

    it 'validates uniqueness of name scoped to user' do
      user = create(:user)
      create(:tracked_deck, name: 'My Deck', user: user)
      duplicate = build(:tracked_deck, name: 'My Deck', user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('has already been taken')
    end

    it 'allows the same deck name for different users' do
      create(:tracked_deck, name: 'My Deck')
      other_deck = build(:tracked_deck, name: 'My Deck')
      expect(other_deck).to be_valid
    end

    it 'validates status inclusion' do
      deck = build(:tracked_deck, status: 'invalid')
      expect(deck).not_to be_valid
    end

    it 'accepts all valid statuses' do
      %w[active worth_upgrading chopping_block retired].each do |status|
        deck = build(:tracked_deck, status: status)
        expect(deck).to be_valid
      end
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:active_deck) { create(:tracked_deck, status: 'active', user: user) }
    let!(:retired_deck) { create(:tracked_deck, status: 'retired', user: user) }
    let!(:chopping_deck) { create(:tracked_deck, status: 'chopping_block', user: user) }

    describe '.active' do
      it 'returns only active decks' do
        expect(described_class.active).to contain_exactly(active_deck)
      end
    end

    describe '.retired' do
      it 'returns only retired decks' do
        expect(described_class.retired).to contain_exactly(retired_deck)
      end
    end

    describe '.not_retired' do
      it 'returns all non-retired decks' do
        expect(described_class.not_retired).to contain_exactly(active_deck, chopping_deck)
      end
    end

    describe '.chopping_block' do
      it 'returns only chopping_block decks' do
        expect(described_class.chopping_block).to contain_exactly(chopping_deck)
      end
    end

    describe '.by_user' do
      it 'returns decks for the given user' do
        other_user = create(:user)
        create(:tracked_deck, user: other_user)
        expect(described_class.by_user(user.id)).to contain_exactly(active_deck, retired_deck, chopping_deck)
      end
    end
  end

  describe '#win_rate' do
    let(:deck) { create(:tracked_deck) }

    context 'with no games' do
      it 'returns 0.0' do
        expect(deck.win_rate).to eq(0.0)
      end
    end

    context 'with games' do
      before do
        create(:commander_game, tracked_deck: deck, user: deck.user, won: true)
        create(:commander_game, tracked_deck: deck, user: deck.user, won: true)
        create(:commander_game, tracked_deck: deck, user: deck.user, won: false)
      end

      it 'returns the correct win percentage' do
        expect(deck.win_rate).to eq(66.7)
      end
    end
  end

  describe '#commander_display_name' do
    context 'without a partner commander' do
      it 'returns only the commander name' do
        card = create(:magic_card, name: 'Atraxa')
        deck = create(:tracked_deck, commander: card)
        expect(deck.commander_display_name).to eq('Atraxa')
      end
    end

    context 'with a partner commander' do
      it 'returns both commander names separated by a slash' do
        card = create(:magic_card, name: 'Thrasios')
        partner = create(:magic_card, name: 'Tymna')
        deck = create(:tracked_deck, commander: card, partner_commander: partner)
        expect(deck.commander_display_name).to eq('Thrasios / Tymna')
      end
    end
  end

  describe '#dropdown_display_name' do
    it 'returns the commander display name followed by the deck name' do
      card = create(:magic_card, name: 'Atraxa')
      deck = create(:tracked_deck, name: 'Superfriends', commander: card)
      expect(deck.dropdown_display_name).to eq('Atraxa - Superfriends')
    end
  end

  describe '#status_badge_class' do
    it 'returns the correct class for each status' do
      expectations = {
        'active' => 'bg-accent-50/20 text-accent-50',
        'worth_upgrading' => 'bg-accent-300/20 text-accent-300',
        'chopping_block' => 'bg-accent-100/20 text-accent-100',
        'retired' => 'bg-gray-500/20 text-gray-400'
      }

      expectations.each do |status, css_class|
        deck = build(:tracked_deck, status: status)
        expect(deck.status_badge_class).to eq(css_class)
      end
    end
  end
end
