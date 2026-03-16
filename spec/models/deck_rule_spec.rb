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

    it 'requires valid applies_to' do
      rule = build(:deck_rule, bracket: bracket, applies_to: 'invalid')
      expect(rule).not_to be_valid
    end

    it 'defaults applies_to to all' do
      rule = build(:deck_rule, bracket: bracket)
      expect(rule.applies_to).to eq('all')
    end

    it 'requires unique rule_type per applies_to and bracket' do
      create(:deck_rule, bracket: bracket, rule_type: 'max_game_changers', applies_to: 'all')
      rule = build(:deck_rule, bracket: bracket, rule_type: 'max_game_changers', applies_to: 'all')
      expect(rule).not_to be_valid
    end

    it 'allows same rule_type on different brackets' do
      other_bracket = create(:bracket, level: 2)
      create(:deck_rule, bracket: bracket, rule_type: 'max_game_changers')
      rule = build(:deck_rule, bracket: other_bracket, rule_type: 'max_game_changers')
      expect(rule).to be_valid
    end

    it 'allows same rule_type with different applies_to on same bracket' do
      create(:deck_rule, bracket: bracket, rule_type: 'max_game_changers', applies_to: 'all')
      rule = build(:deck_rule, bracket: bracket, rule_type: 'max_game_changers', applies_to: 'commander_deck')
      expect(rule).to be_valid
    end

    it 'allows bracket_id to be nil (global rule)' do
      rule = build(:deck_rule, bracket: nil, rule_type: 'max_game_changers', name: 'Global GC')
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

    describe '.global' do
      let!(:global_rule) { create(:deck_rule, bracket: nil, rule_type: 'max_copies_per_card', name: 'Global') }

      it 'returns rules with no bracket' do
        expect(DeckRule.global).to contain_exactly(global_rule)
      end
    end

    describe '.applicable_to' do
      let!(:all_rule) {
        create(:deck_rule, bracket: bracket, applies_to: 'all', rule_type: 'max_copies_per_card', name: 'All')
      }
      let!(:commander_rule) do
        create(:deck_rule, bracket: bracket, applies_to: 'commander_deck',
                           rule_type: 'max_deck_size', name: 'Commander Only', value: 100)
      end

      it 'returns rules matching the type or all' do
        expect(DeckRule.applicable_to('commander_deck')).to contain_exactly(enabled_rule, disabled_rule, all_rule,
                                                                            commander_rule)
      end

      it 'excludes rules for other types' do
        expect(DeckRule.applicable_to('deck')).to contain_exactly(enabled_rule, disabled_rule, all_rule)
      end
    end
  end
end
