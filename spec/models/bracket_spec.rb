require 'rails_helper'

RSpec.describe Bracket, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      bracket = build(:bracket)
      expect(bracket).to be_valid
    end

    it 'requires level' do
      bracket = build(:bracket, level: nil)
      expect(bracket).not_to be_valid
    end

    it 'requires unique level' do
      create(:bracket, level: 1)
      bracket = build(:bracket, level: 1)
      expect(bracket).not_to be_valid
    end

    it 'requires name' do
      bracket = build(:bracket, name: nil)
      expect(bracket).not_to be_valid
    end
  end

  describe 'associations' do
    it 'destroys deck_rules when destroyed' do
      bracket = create(:bracket, level: 1)
      create(:deck_rule, bracket: bracket)

      expect { bracket.destroy }.to change(DeckRule, :count).by(-1)
    end
  end

  describe 'scopes' do
    let!(:enabled_bracket) { create(:bracket, level: 1, enabled: true) }
    let!(:disabled_bracket) { create(:bracket, level: 2, enabled: false) }

    describe '.enabled' do
      it 'returns only enabled brackets' do
        expect(Bracket.enabled).to contain_exactly(enabled_bracket)
      end
    end

    describe '.ordered' do
      let!(:bracket_three) { create(:bracket, level: 3) }

      it 'returns brackets ordered by level' do
        expect(Bracket.ordered.pluck(:level)).to eq([1, 2, 3])
      end
    end
  end
end
