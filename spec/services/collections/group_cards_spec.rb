require 'rails_helper'

RSpec.describe Collections::GroupCards, type: :service do
  let!(:rare_card) { create(:magic_card, rarity: 'rare') }
  let!(:common_card) { create(:magic_card, rarity: 'common') }

  let(:cards) { MagicCard.where(id: [rare_card.id, common_card.id]) }

  context 'with no grouping' do
    it 'returns all cards in one group' do
      result = described_class.call(cards: cards, grouping: 'none')
      expect(result.keys).to eq(['All Cards'])
      expect(result['All Cards'].size).to eq(2)
    end
  end

  context 'grouping by rarity' do
    it 'groups cards by rarity' do
      result = described_class.call(cards: cards, grouping: 'rarity')
      expect(result.keys).to include('Rare', 'Common')
    end

    it 'sorts groups in rarity order' do
      result = described_class.call(cards: cards, grouping: 'rarity')
      keys = result.keys
      expect(keys.index('Rare')).to be < keys.index('Common')
    end
  end

  context 'with empty cards' do
    it 'returns empty hash' do
      result = described_class.call(cards: [], grouping: 'rarity')
      expect(result).to eq({})
    end
  end

  context 'with invalid grouping' do
    it 'defaults to none' do
      result = described_class.call(cards: cards, grouping: 'invalid')
      expect(result.keys).to eq(['All Cards'])
    end
  end

  # a mono-red card with a {G} ability: red by color, red-green by identity
  context 'grouping by color' do
    def add_colors(join_model, card, *names)
      names.each { |name| join_model.create!(magic_card: card, color: Color.find_or_create_by!(name: name)) }
    end

    let(:red_card) { create(:magic_card) }
    let(:azorius_card) { create(:magic_card) }
    let(:land) { create(:magic_card, card_type: 'Land') }

    let(:color_cards) do
      add_colors(MagicCardColor, red_card, 'R')
      add_colors(MagicCardColorIdent, red_card, 'R', 'G')
      add_colors(MagicCardColor, azorius_card, 'W', 'U')
      add_colors(MagicCardColorIdent, land, 'G')

      MagicCard.where(id: [red_card.id, azorius_card.id, land.id]).preload(:colors)
    end

    it 'groups by the card color, spelled out, in color order' do
      result = described_class.call(cards: color_cards, grouping: 'color')

      expect(result).to eq('Red' => [red_card], 'Colorless' => [land], 'Multicolor' => [azorius_card])
    end
  end
end
