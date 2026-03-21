require 'rails_helper'

RSpec.describe CardRole, type: :model do
  subject(:card_role) do
    described_class.new(
      scryfall_oracle_id: SecureRandom.uuid,
      role: 'ramp',
      effect: 'mana_rock',
      confidence: 0.9,
      source: 'pattern'
    )
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(card_role).to be_valid
    end

    it 'requires scryfall_oracle_id' do
      card_role.scryfall_oracle_id = nil
      expect(card_role).not_to be_valid
    end

    it 'requires role' do
      card_role.role = nil
      expect(card_role).not_to be_valid
    end

    it 'requires effect' do
      card_role.effect = nil
      expect(card_role).not_to be_valid
    end

    it 'validates role inclusion in ROLES' do
      card_role.role = 'invalid_role'
      expect(card_role).not_to be_valid
    end

    it 'validates confidence is between 0.0 and 1.0' do
      card_role.confidence = 1.5
      expect(card_role).not_to be_valid
    end

    it 'validates confidence is not negative' do
      card_role.confidence = -0.1
      expect(card_role).not_to be_valid
    end

    it 'enforces uniqueness on scryfall_oracle_id, role, effect' do
      card_role.save!
      duplicate = described_class.new(
        scryfall_oracle_id: card_role.scryfall_oracle_id,
        role: card_role.role,
        effect: card_role.effect,
        confidence: 0.5,
        source: 'keyword'
      )
      expect(duplicate).not_to be_valid
    end
  end

  describe 'scopes' do
    let(:oracle_id) { SecureRandom.uuid }

    before do
      described_class.create!(scryfall_oracle_id: oracle_id, role: 'ramp', effect: 'mana_rock', confidence: 0.9)
      described_class.create!(scryfall_oracle_id: oracle_id, role: 'removal', effect: 'targeted_removal',
                              confidence: 0.5)
      described_class.create!(scryfall_oracle_id: SecureRandom.uuid, role: 'ramp', effect: 'land_ramp',
                              confidence: 0.95)
    end

    describe '.for_oracle_id' do
      it 'returns roles for the given oracle_id' do
        expect(described_class.for_oracle_id(oracle_id).count).to eq(2)
      end
    end

    describe '.for_role' do
      it 'returns roles matching the given role' do
        expect(described_class.for_role('ramp').count).to eq(2)
      end
    end

    describe '.high_confidence' do
      it 'returns roles with confidence >= 0.7' do
        expect(described_class.high_confidence.count).to eq(2)
      end
    end
  end

  describe 'constants' do
    it 'defines ROLES' do
      expect(CardRole::ROLES).to include('ramp', 'removal', 'card_draw', 'tutor')
    end

    it 'defines EFFECTS for each role' do
      CardRole::ROLES.each do |role|
        expect(CardRole::EFFECTS).to have_key(role)
        expect(CardRole::EFFECTS[role]).to be_an(Array)
      end
    end
  end
end
