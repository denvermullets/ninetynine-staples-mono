require 'rails_helper'

RSpec.describe DeckRule, type: :model do
  describe 'validations' do
    let(:bracket) { create(:bracket, level: 1) }

    it 'is valid with valid attributes' do
      rule = build(:deck_rule, bracket: bracket)
      expect(rule).to be_valid
    end

    it 'requires name' do
      rule = build(:deck_rule, bracket: bracket, name: nil)
      expect(rule).not_to be_valid
    end

    it 'requires rule_type' do
      rule = build(:deck_rule, bracket: bracket, rule_type: nil)
      expect(rule).not_to be_valid
    end

    it 'requires valid rule_type' do
      rule = build(:deck_rule, bracket: bracket, rule_type: 'invalid')
      expect(rule).not_to be_valid
    end

    it 'requires value' do
      rule = build(:deck_rule, bracket: bracket, value: nil)
      expect(rule).not_to be_valid
    end

    it 'requires non-negative value' do
      rule = build(:deck_rule, bracket: bracket, value: -1)
      expect(rule).not_to be_valid
    end

    it 'requires unique rule_type per bracket' do
      create(:deck_rule, bracket: bracket, rule_type: 'max_game_changers')
      rule = build(:deck_rule, bracket: bracket, rule_type: 'max_game_changers')
      expect(rule).not_to be_valid
    end

    it 'allows same rule_type on different brackets' do
      other_bracket = create(:bracket, level: 2)
      create(:deck_rule, bracket: bracket, rule_type: 'max_game_changers')
      rule = build(:deck_rule, bracket: other_bracket, rule_type: 'max_game_changers')
      expect(rule).to be_valid
    end
  end

  describe 'scopes' do
    let(:bracket) { create(:bracket, level: 1) }
    let!(:enabled_rule) { create(:deck_rule, bracket: bracket, enabled: true) }
    let!(:disabled_rule) { create(:deck_rule, bracket: bracket, rule_type: 'max_deck_size', enabled: false) }

    describe '.enabled' do
      it 'returns only enabled rules' do
        expect(DeckRule.enabled).to contain_exactly(enabled_rule)
      end
    end
  end
end
