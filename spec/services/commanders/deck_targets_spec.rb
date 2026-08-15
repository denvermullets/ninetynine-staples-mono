require 'rails_helper'

RSpec.describe Commanders::DeckTargets, type: :service do
  it 'only targets roles the role taxonomy actually knows about' do
    expect(described_class::TARGETS.keys - CardRole::ROLES).to be_empty
  end

  it 'exposes the roles in display order with manabase last' do
    expect(described_class::ROLES.last).to eq('manabase')
  end

  describe '.for' do
    it 'returns the target count for a checklist role' do
      expect(described_class.for('ramp')).to eq(10)
    end

    it 'returns nil for an archetype role with no universal target' do
      expect(described_class.for('sacrifice')).to be_nil
    end
  end
end
