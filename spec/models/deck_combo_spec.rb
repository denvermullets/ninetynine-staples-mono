require 'rails_helper'

RSpec.describe DeckCombo, type: :model do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:combo) { Combo.create!(spellbook_id: 'test-combo') }

  describe 'validations' do
    it 'requires combo_type to be included or almost_included' do
      dc = DeckCombo.new(collection: deck, combo: combo, combo_type: 'invalid')
      expect(dc).not_to be_valid
      expect(dc.errors[:combo_type]).to be_present
    end

    it 'accepts included' do
      dc = DeckCombo.new(collection: deck, combo: combo, combo_type: 'included')
      expect(dc).to be_valid
    end

    it 'accepts almost_included' do
      dc = DeckCombo.new(collection: deck, combo: combo, combo_type: 'almost_included')
      expect(dc).to be_valid
    end
  end

  describe 'scopes' do
    let!(:included) { DeckCombo.create!(collection: deck, combo: combo, combo_type: 'included') }
    let(:combo2) { Combo.create!(spellbook_id: 'test-combo-2') }
    let!(:almost) { DeckCombo.create!(collection: deck, combo: combo2, combo_type: 'almost_included') }

    it '.included_combos returns only included' do
      expect(DeckCombo.included_combos).to eq([included])
    end

    it '.almost_included returns only almost_included' do
      expect(DeckCombo.almost_included).to eq([almost])
    end
  end

  describe 'associations' do
    it 'destroys missing cards on destroy' do
      dc = DeckCombo.create!(collection: deck, combo: combo, combo_type: 'almost_included')
      dc.deck_combo_missing_cards.create!(card_name: 'Missing Card')
      expect { dc.destroy }.to change(DeckComboMissingCard, :count).by(-1)
    end
  end
end
