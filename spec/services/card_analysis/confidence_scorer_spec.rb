require 'rails_helper'

RSpec.describe CardAnalysis::ConfidenceScorer, type: :service do
  let(:oracle_id) { SecureRandom.uuid }

  describe '#call' do
    it 'scores a match as the product of candidate confidence and target weight' do
      result = described_class.call(
        rows: [[oracle_id, 'ramp', 'mana_rock', 0.8]],
        targets: { %w[ramp mana_rock] => 0.5 }
      )

      expect(result[oracle_id][:score]).to be_within(0.0001).of(0.4)
    end

    it 'sums across every matched pair' do
      result = described_class.call(
        rows: [[oracle_id, 'ramp', 'mana_rock', 0.8], [oracle_id, 'removal', 'bounce', 0.5]],
        targets: { %w[ramp mana_rock] => 1.0, %w[removal bounce] => 1.0 }
      )

      expect(result[oracle_id][:score]).to be_within(0.0001).of(1.3)
    end

    it 'ignores roles that are not targets' do
      result = described_class.call(
        rows: [[oracle_id, 'mill', 'self_mill', 0.9]],
        targets: { %w[ramp mana_rock] => 1.0 }
      )

      expect(result).to be_empty
    end

    it 'collects the matched role and effect for each hit' do
      result = described_class.call(
        rows: [[oracle_id, 'ramp', 'mana_rock', 0.8]],
        targets: { %w[ramp mana_rock] => 1.0 }
      )

      expect(result[oracle_id][:matched_roles]).to eq([{ role: 'ramp', effect: 'mana_rock' }])
    end
  end

  describe '.rows_for' do
    it 'returns oracle id, role, effect and confidence for the given oracle ids' do
      create(:card_role, scryfall_oracle_id: oracle_id, role: 'tutor', effect: 'tutor_to_hand', confidence: 0.75)
      create(:card_role, scryfall_oracle_id: SecureRandom.uuid)

      expect(described_class.rows_for([oracle_id])).to eq([[oracle_id, 'tutor', 'tutor_to_hand', 0.75]])
    end
  end
end
