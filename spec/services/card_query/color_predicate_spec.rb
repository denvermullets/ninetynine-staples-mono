require 'rails_helper'

RSpec.describe CardQuery::ColorPredicate, type: :service do
  let!(:mono_black) { card_with('Dark Ritual', %w[B]) }
  let!(:azorius) { card_with('Teferi', %w[W U]) }
  let!(:esper) { card_with('Sharuum', %w[W U B]) }
  let!(:colorless) { card_with('Sol Ring', []) }

  def card_with(name, letters)
    card = create(:magic_card, name: name)
    letters.each do |letter|
      MagicCardColor.create!(magic_card: card, color: Color.find_or_create_by!(name: letter))
    end
    card
  end

  def matching(operator, value, join_table: 'magic_card_colors')
    MagicCard.where(*described_class.call(operator: operator, value: value, join_table: join_table))
  end

  describe 'letters' do
    it 'accepts letters, separators and colour names' do
      expect(described_class.letters('wu')).to eq(%w[W U])
      expect(described_class.letters('w/u')).to eq(%w[W U])
      expect(described_class.letters('W, U')).to eq(%w[W U])
      expect(described_class.letters('white')).to eq(['W'])
      expect(described_class.letters('colorless')).to eq(['C'])
    end
  end

  describe 'contains (`:` / `>=`)' do
    it 'matches cards holding at least the given colors' do
      expect(matching('>=', 'wu')).to contain_exactly(azorius, esper)
    end

    it 'matches on a single color' do
      expect(matching('>=', 'b')).to contain_exactly(mono_black, esper)
    end
  end

  describe 'exactly (`=`)' do
    it 'matches only the precise color set' do
      expect(matching('=', 'wu')).to contain_exactly(azorius)
    end
  end

  describe 'subset (`<=`)' do
    # Scryfall counts colorless as a subset of everything
    it 'matches cards using nothing outside the given colors, including colorless' do
      expect(matching('<=', 'wu')).to contain_exactly(azorius, colorless)
    end
  end

  describe 'strict superset (`>`)' do
    it 'excludes the exact match' do
      expect(matching('>', 'wu')).to contain_exactly(esper)
    end
  end

  describe 'strict subset (`<`)' do
    it 'excludes the exact match' do
      expect(matching('<', 'wu')).to contain_exactly(colorless)
    end
  end

  describe 'not exactly (`!=`)' do
    it 'returns everything but the precise color set' do
      expect(matching('!=', 'wu')).to contain_exactly(mono_black, esper, colorless)
    end
  end

  describe 'colorless' do
    it 'matches only cards with no color rows' do
      expect(matching(':', 'c')).to contain_exactly(colorless)
    end

    it 'inverts for !=' do
      expect(matching('!=', 'c')).to contain_exactly(mono_black, azorius, esper)
    end
  end

  describe 'color identity' do
    let!(:identity_card) do
      card = create(:magic_card, name: 'Kess')
      %w[U B R].each do |letter|
        MagicCardColorIdent.create!(magic_card: card, color: Color.find_or_create_by!(name: letter))
      end
      card
    end

    it 'reads the identity join table instead of the colors one' do
      result = matching('>=', 'ub', join_table: 'magic_card_color_idents')

      expect(result).to contain_exactly(identity_card)
    end
  end
end
