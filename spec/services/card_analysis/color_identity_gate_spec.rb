require 'rails_helper'

RSpec.describe CardAnalysis::ColorIdentityGate, type: :service do
  let(:green) { Color.find_or_create_by!(name: 'G') }
  let(:red) { Color.find_or_create_by!(name: 'R') }

  def card_with_colors(*colors)
    card = create(:magic_card, scryfall_oracle_id: SecureRandom.uuid, card_side: nil)
    colors.each { |color| MagicCardColorIdent.create!(magic_card: card, color: color) }
    card
  end

  describe '.color_ids_for' do
    it 'returns the union of the given cards colour identities' do
      first = card_with_colors(green)
      second = card_with_colors(red)

      expect(described_class.color_ids_for(magic_card_ids: [first.id, second.id]))
        .to eq([green.id, red.id].to_set)
    end

    it 'returns an empty set for a colourless card' do
      expect(described_class.color_ids_for(magic_card_ids: [card_with_colors.id])).to be_empty
    end
  end

  describe '#call' do
    it 'keeps candidates inside the allowed identity' do
      card = card_with_colors(green)

      expect(described_class.call(oracle_ids: [card.scryfall_oracle_id], allowed_color_ids: [green.id].to_set))
        .to eq([card.scryfall_oracle_id])
    end

    it 'drops candidates with a colour outside the allowed identity' do
      card = card_with_colors(green, red)

      expect(described_class.call(oracle_ids: [card.scryfall_oracle_id], allowed_color_ids: [green.id].to_set))
        .to be_empty
    end

    # Colourless cards have no magic_card_color_idents rows at all, so they must fall through to an empty
    # set rather than being treated as unknown and dropped.
    it 'keeps colourless candidates in every identity' do
      card = card_with_colors

      expect(described_class.call(oracle_ids: [card.scryfall_oracle_id], allowed_color_ids: [green.id].to_set))
        .to eq([card.scryfall_oracle_id])
    end

    it 'preserves the order it was given' do
      first = card_with_colors(green)
      second = card_with_colors
      ids = [second.scryfall_oracle_id, first.scryfall_oracle_id]

      expect(described_class.call(oracle_ids: ids, allowed_color_ids: [green.id].to_set)).to eq(ids)
    end
  end
end
