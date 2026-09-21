require 'rails_helper'

RSpec.describe DeckComparison::GroupCards, type: :service do
  let(:creature) do
    create(:magic_card, name: 'Atraxa', card_type: 'Creature', mana_value: 4, rarity: 'mythic',
                        edhrec_rank: 50, edhrec_saltiness: 1.5)
  end
  let(:instant) do
    create(:magic_card, name: 'Brainstorm', card_type: 'Instant', mana_value: 1, rarity: 'common',
                        edhrec_rank: 10, edhrec_saltiness: 0.2)
  end
  let(:artifact) do
    create(:magic_card, name: 'Sol Ring', card_type: 'Artifact', mana_value: 1, rarity: 'uncommon',
                        edhrec_rank: 1, edhrec_saltiness: 2.5)
  end

  def row(magic_card, board_type: 'mainboard', unit_price: 1.0)
    DeckComparison::Row.new(magic_card: magic_card, board_type: board_type, quantity_a: 1, quantity_b: nil,
                            unit_price: unit_price)
  end

  let(:cards) do
    [row(creature, board_type: 'commander', unit_price: 9.0), row(instant, unit_price: 0.5),
     row(artifact, unit_price: 3.0)]
  end

  def names(rows)
    rows.map { |card| card.magic_card.name }
  end

  it 'groups by type with the commander first' do
    result = described_class.call(cards: cards, grouping: 'type', sort_by: 'name')

    expect(result.keys).to eq(%w[Commander Instant Artifact])
  end

  %w[zone real_vs_proxy nonsense].each do |grouping|
    it "falls back to type for #{grouping}" do
      result = described_class.call(cards: cards, grouping: grouping, sort_by: 'name')

      expect(result.keys).to eq(%w[Commander Instant Artifact])
    end
  end

  it 'groups by every option it offers' do
    described_class::GROUPING_OPTIONS.each do |grouping|
      result = described_class.call(cards: cards, grouping: grouping, sort_by: 'name')

      expect(result.values.flatten).to match_array(cards)
    end
  end

  it 'returns nothing for no cards' do
    expect(described_class.call(cards: [], grouping: 'type', sort_by: 'name')).to eq({})
  end

  describe 'sorting rows' do
    def sorted(sort_by)
      names(described_class.call(cards: cards, grouping: 'none', sort_by: sort_by)['All Cards'])
    end

    it 'offers the precon sort options' do
      expect(described_class::SORT_OPTIONS).to eq(%w[name mana_value price rarity edhrec salt])
    end

    it { expect(sorted('name')).to eq(['Brainstorm', 'Sol Ring']) }
    it { expect(sorted('mana_value')).to eq(['Brainstorm', 'Sol Ring']) }
    it { expect(sorted('price')).to eq(['Brainstorm', 'Sol Ring']) }
    it { expect(sorted('rarity')).to eq(['Sol Ring', 'Brainstorm']) }
    it { expect(sorted('edhrec')).to eq(['Sol Ring', 'Brainstorm']) }
    it { expect(sorted('salt')).to eq(['Sol Ring', 'Brainstorm']) }
  end
end
