require 'rails_helper'

RSpec.describe Combo, type: :model do
  describe 'validations' do
    it 'requires spellbook_id' do
      combo = Combo.new(spellbook_id: nil)
      expect(combo).not_to be_valid
      expect(combo.errors[:spellbook_id]).to be_present
    end

    it 'requires unique spellbook_id' do
      Combo.create!(spellbook_id: 'abc-123')
      combo = Combo.new(spellbook_id: 'abc-123')
      expect(combo).not_to be_valid
      expect(combo.errors[:spellbook_id]).to be_present
    end
  end

  describe 'associations' do
    it 'has many combo_cards' do
      combo = Combo.create!(spellbook_id: 'test-1')
      combo.combo_cards.create!(card_name: 'Test Card', oracle_id: SecureRandom.uuid)
      expect(combo.combo_cards.count).to eq(1)
    end

    it 'destroys combo_cards on destroy' do
      combo = Combo.create!(spellbook_id: 'test-2')
      combo.combo_cards.create!(card_name: 'Test Card', oracle_id: SecureRandom.uuid)
      expect { combo.destroy }.to change(ComboCard, :count).by(-1)
    end
  end
end
