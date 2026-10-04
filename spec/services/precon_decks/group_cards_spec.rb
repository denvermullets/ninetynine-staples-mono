require 'rails_helper'

RSpec.describe PreconDecks::GroupCards, type: :service do
  let(:boxset) { create(:boxset) }
  let(:creature_card) { create(:magic_card, card_type: 'Creature', mana_value: 3, rarity: 'rare', boxset: boxset) }
  let(:instant_card) {
    create(:magic_card, card_type: 'Instant', mana_value: 1, rarity: 'common', boxset: create(:boxset))
  }

  let(:precon_deck) { PreconDeck.create!(code: 'TST', file_name: 'test_deck', name: 'Test Deck') }

  let!(:commander_pdc) do
    PreconDeckCard.create!(
      precon_deck: precon_deck, magic_card: creature_card,
      board_type: 'commander', quantity: 1
    )
  end

  let!(:mainboard_pdc) do
    PreconDeckCard.create!(
      precon_deck: precon_deck, magic_card: instant_card,
      board_type: 'mainBoard', quantity: 4
    )
  end

  let(:cards) { precon_deck.precon_deck_cards.includes(magic_card: :boxset) }

  context 'grouping by type' do
    it 'separates commanders into their own section' do
      result = described_class.call(cards: cards, grouping: 'type')
      expect(result.keys.first).to eq('Commander')
    end

    it 'groups main board cards by type' do
      result = described_class.call(cards: cards, grouping: 'type')
      expect(result.keys).to include('Instant')
    end
  end

  context 'grouping by zone' do
    it 'groups by board type' do
      result = described_class.call(cards: cards, grouping: 'zone')
      expect(result.keys).to include('Commander', 'Main Board')
    end
  end

  context 'grouping by none' do
    it 'separates commanders and puts rest in All Cards' do
      result = described_class.call(cards: cards, grouping: 'none')
      expect(result.keys).to include('Commander', 'All Cards')
    end
  end

  context 'with empty cards' do
    it 'returns empty hash' do
      result = described_class.call(cards: [], grouping: 'type')
      expect(result).to eq({})
    end
  end

  context 'when sorting by price' do
    let(:cheap_card) { create(:magic_card, name: 'Cheap', normal_price: 1.0, foil_price: 2.0, boxset: boxset) }
    let(:pricey_foil_card) do
      create(:magic_card, name: 'Pricey Foil', normal_price: 2.0, foil_price: 50.0, boxset: boxset)
    end

    let(:price_deck) { PreconDeck.create!(code: 'PRC', file_name: 'price_deck', name: 'Price Deck') }

    let!(:cheap_pdc) do
      PreconDeckCard.create!(precon_deck: price_deck, magic_card: cheap_card,
                             board_type: 'mainBoard', quantity: 1)
    end

    let!(:pricey_foil_pdc) do
      PreconDeckCard.create!(precon_deck: price_deck, magic_card: pricey_foil_card,
                             board_type: 'mainBoard', is_foil: true, quantity: 1)
    end

    it 'ranks a foil card by its foil price rather than its normal price' do
      result = described_class.call(cards: [pricey_foil_pdc, cheap_pdc], grouping: 'none', sort_by: 'price')
      names = result['All Cards'].map { |c| c.magic_card.name }
      expect(names).to eq(['Cheap', 'Pricey Foil'])
    end
  end

  context 'when sorting by name' do
    it 'orders alphabetically within a group' do
      result = described_class.call(cards: cards, grouping: 'none', sort_by: 'name')
      names = result['All Cards'].map { |c| c.magic_card.name }
      expect(names).to eq(names.sort)
    end
  end

  # a mono-red card with a {G} ability: red by color, red-green by identity. The land has no color
  # but a green identity from its mana ability
  context 'when color and color identity differ' do
    def add_colors(join_model, card, *names)
      names.each { |name| join_model.create!(magic_card: card, color: Color.find_or_create_by!(name: name)) }
    end

    let(:color_deck) { PreconDeck.create!(code: 'CLR', file_name: 'color_deck', name: 'Color Deck') }
    let(:red_card) { create(:magic_card, card_type: 'Creature', boxset: boxset) }
    let(:green_land) { create(:magic_card, card_type: 'Land', boxset: boxset) }

    let(:color_cards) do
      add_colors(MagicCardColor, red_card, 'R')
      add_colors(MagicCardColorIdent, red_card, 'R', 'G')
      add_colors(MagicCardColorIdent, green_land, 'G')

      [red_card, green_land].each do |card|
        PreconDeckCard.create!(precon_deck: color_deck, magic_card: card, board_type: 'mainBoard', quantity: 1)
      end
      color_deck.precon_deck_cards.includes(magic_card: [:colors, { magic_card_color_idents: :color }])
    end

    def group_names(grouping)
      described_class.call(cards: color_cards, grouping: grouping).transform_values do |pdcs|
        pdcs.map(&:magic_card)
      end
    end

    it 'groups Color by the card color' do
      expect(group_names('color')).to eq('R' => [red_card], 'Colorless' => [green_land])
    end

    it 'groups Color Identity by the identity' do
      expect(group_names('color_identity')).to eq('GR' => [red_card], 'G' => [green_land])
    end
  end
end
