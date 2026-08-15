require 'rails_helper'

RSpec.describe CardAnalysis::CommanderThemes, type: :service do
  let(:oracle_id) { SecureRandom.uuid }

  def commander(text:, subtypes: [])
    card = create(:magic_card, scryfall_oracle_id: oracle_id, text: text,
                               card_type: 'Legendary Creature - Goblin')
    subtypes.each do |name|
      card.sub_types << SubType.find_or_create_by!(name: name)
    end
    card
  end

  describe 'role weights' do
    it 'weights a role by the commander own confidence in it' do
      card = commander(text: 'Sacrifice another creature: draw a card.')
      create(:card_role, scryfall_oracle_id: oracle_id, role: 'sacrifice',
                         effect: 'sacrifice_outlet', confidence: 0.9)

      expect(described_class.call(commander: card)[:role_weights]).to eq({ %w[sacrifice sacrifice_outlet] => 0.9 })
    end

    # Below HIGH_CONFIDENCE the pattern rules are guessing, and a guess is not a theme.
    it 'ignores roles below the high confidence threshold' do
      card = commander(text: 'Flying.')
      create(:card_role, scryfall_oracle_id: oracle_id, role: 'evasion',
                         effect: 'flying_grant', confidence: 0.4)

      expect(described_class.call(commander: card)[:role_weights]).to be_empty
    end
  end

  describe 'tribal subtypes' do
    it 'picks up a creature type the rules text names' do
      card = commander(text: 'Create X 1/1 red Goblin creature tokens.', subtypes: ['Goblin'])
      create(:magic_card, card_type: 'Creature - Goblin').sub_types << SubType.find_by!(name: 'Goblin')

      expect(described_class.call(commander: card)[:subtypes]).to eq(['Goblin'])
    end

    # A commander is not tribal just because of its type line - Atraxa is a Phyrexian Angel Horror and a
    # proliferate deck, not an Angel deck.
    it 'ignores the commander own creature types when the text never mentions them' do
      card = commander(text: 'At the beginning of your end step, proliferate.', subtypes: ['Angel'])
      create(:magic_card, card_type: 'Creature - Angel').sub_types << SubType.find_by!(name: 'Angel')

      expect(described_class.call(commander: card)[:subtypes]).to be_empty
    end

    # "You" is a real row in sub_types and matches the partner reminder text on dozens of commanders.
    it 'ignores subtype names that are only ordinary capitalised words in rules text' do
      SubType.find_or_create_by!(name: 'You')
      card = commander(text: 'Partner (You can have two commanders if both have partner.)')

      expect(described_class.call(commander: card)[:subtypes]).to be_empty
    end

    it 'returns no subtypes for a commander with no rules text' do
      card = commander(text: nil)

      expect(described_class.call(commander: card)[:subtypes]).to be_empty
    end
  end
end
