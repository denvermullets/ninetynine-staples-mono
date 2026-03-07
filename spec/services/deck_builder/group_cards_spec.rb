require 'rails_helper'

RSpec.describe DeckBuilder::GroupCards, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }

  let(:creature_card) {
    create(:magic_card, card_type: 'Creature', mana_value: 3, rarity: 'rare', boxset: create(:boxset))
  }
  let(:instant_card) {
    create(:magic_card, card_type: 'Instant', mana_value: 1, rarity: 'common', boxset: create(:boxset))
  }
  let(:land_card) { create(:magic_card, card_type: 'Land', mana_value: 0, rarity: 'common', boxset: create(:boxset)) }

  let!(:cmc_creature) do
    create(:collection_magic_card,
           collection: deck,
           magic_card: creature_card,
           staged: false,
           needed: false,
           quantity: 1,
           foil_quantity: 0)
  end

  let!(:cmc_instant) do
    create(:collection_magic_card,
           collection: deck,
           magic_card: instant_card,
           staged: false,
           needed: false,
           quantity: 1,
           foil_quantity: 0)
  end

  let!(:cmc_land) do
    create(:collection_magic_card,
           collection: deck,
           magic_card: land_card,
           staged: false,
           needed: false,
           quantity: 1,
           foil_quantity: 0)
  end

  let(:cards) { [cmc_creature, cmc_instant, cmc_land] }

  context 'when grouping by type' do
    subject { described_class.call(cards: cards, grouping: 'type', sort_by: 'mana_value') }

    it 'groups cards by their primary type' do
      result = subject
      expect(result.keys).to include('Creature', 'Instant', 'Land')
    end

    it 'sorts groups in type order' do
      result = subject
      keys = result.keys
      expect(keys.index('Creature')).to be < keys.index('Instant')
      expect(keys.index('Instant')).to be < keys.index('Land')
    end
  end

  context 'when grouping by mana value' do
    subject { described_class.call(cards: cards, grouping: 'mana_value', sort_by: 'name') }

    it 'groups cards by mana value' do
      result = subject
      expect(result.keys).to include('0', '1', '3')
    end
  end

  context 'when grouping by rarity' do
    subject { described_class.call(cards: cards, grouping: 'rarity', sort_by: 'name') }

    it 'groups cards by rarity' do
      result = subject
      expect(result.keys).to include('Rare', 'Common')
    end
  end

  context 'when grouping by none' do
    subject { described_class.call(cards: cards, grouping: 'none', sort_by: 'name') }

    it 'puts all cards in one group' do
      result = subject
      expect(result.keys).to eq(['All Cards'])
      expect(result['All Cards'].size).to eq(3)
    end
  end

  context 'with commander cards' do
    let!(:commander_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: creature_card,
             board_type: 'commander',
             staged: false,
             needed: false,
             quantity: 1,
             foil_quantity: 0)
    end

    subject { described_class.call(cards: [commander_card, cmc_instant], grouping: 'type', sort_by: 'name') }

    it 'separates commanders into their own section' do
      result = subject
      expect(result.keys.first).to eq('Commander')
    end
  end

  context 'with empty cards' do
    subject { described_class.call(cards: [], grouping: 'type', sort_by: 'name') }

    it 'returns empty hash' do
      expect(subject).to eq({})
    end
  end

  context 'with invalid grouping' do
    subject { described_class.call(cards: cards, grouping: 'invalid', sort_by: 'name') }

    it 'defaults to type grouping' do
      result = subject
      expect(result.keys).to include('Creature', 'Instant', 'Land')
    end
  end
end
