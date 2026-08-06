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

  context 'when sorting by price' do
    let(:cheap_card) { create(:magic_card, name: 'Cheap', normal_price: 1.0, foil_price: 2.0, boxset: create(:boxset)) }
    let(:pricey_foil_card) do
      create(:magic_card, name: 'Pricey Foil', normal_price: 2.0, foil_price: 50.0, boxset: create(:boxset))
    end

    let!(:cmc_cheap) do
      create(:collection_magic_card, collection: deck, magic_card: cheap_card,
                                     staged: false, needed: false, quantity: 1, foil_quantity: 0)
    end

    let!(:cmc_pricey_foil) do
      create(:collection_magic_card, collection: deck, magic_card: pricey_foil_card,
                                     staged: false, needed: false, quantity: 0, foil_quantity: 1)
    end

    subject do
      described_class.call(cards: [cmc_pricey_foil, cmc_cheap], grouping: 'none', sort_by: 'price')
    end

    it 'ranks a foil row by its foil price rather than its normal price' do
      names = subject['All Cards'].map { |c| c.magic_card.name }
      expect(names).to eq(['Cheap', 'Pricey Foil'])
    end
  end

  context 'when sorting a group' do
    subject { described_class.call(cards: cards, grouping: 'none', sort_by: sort_key) }

    def sorted_names = subject['All Cards'].map { |c| c.magic_card.name }

    context 'by name' do
      let(:sort_key) { 'name' }

      it 'orders alphabetically' do
        expect(sorted_names).to eq(sorted_names.sort)
      end
    end

    context 'by mana value' do
      let(:sort_key) { 'mana_value' }

      it 'orders cheapest mana value first' do
        mana_values = subject['All Cards'].map { |c| c.magic_card.mana_value }
        expect(mana_values).to eq([0, 1, 3])
      end
    end

    context 'by rarity' do
      let(:sort_key) { 'rarity' }

      it 'orders rare before common' do
        rarities = subject['All Cards'].map { |c| c.magic_card.rarity }
        expect(rarities.first).to eq('rare')
      end
    end
  end
end
