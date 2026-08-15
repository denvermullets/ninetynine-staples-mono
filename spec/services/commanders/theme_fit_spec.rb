require 'rails_helper'

RSpec.describe Commanders::ThemeFit, type: :service do
  subject(:result) { call }

  def call(role_weights: {}, subtypes: [], effect_counts: {}, tribe_counts: {})
    described_class.call(role_weights: role_weights, subtypes: subtypes,
                         effect_counts: effect_counts, tribe_counts: tribe_counts)
  end

  # Roughly a third of the format has no high-confidence card_roles row at all. Scoring those at zero
  # would bury them under commanders whose only advantage is being legible to the taxonomy.
  describe 'a commander with no detected theme' do
    it 'scores neutral rather than zero' do
      expect(result[:score]).to eq(described_class::NEUTRAL)
    end

    it 'says so, so the page can order it on completeness instead' do
      expect(result[:themed]).to be(false)
    end
  end

  describe 'role themes' do
    it 'scores zero when the collection has nothing doing what the commander wants' do
      scored = call(role_weights: { %w[sacrifice sacrifice_outlet] => 0.9 })

      expect(scored[:score]).to eq(0.0)
    end

    it 'scores full once the theme is supported' do
      scored = call(role_weights: { %w[sacrifice sacrifice_outlet] => 0.9 },
                    effect_counts: { %w[sacrifice sacrifice_outlet] => described_class::SUPPORT.to_i })

      expect(scored[:score]).to eq(1.0)
    end

    # Without the cap a commander themed into manabase would outscore everything, because manabase is
    # the role every collection has most of.
    it 'saturates, so a huge pile of one effect is worth no more than enough of it' do
      enough = call(role_weights: { %w[ramp mana_rock] => 0.9 },
                    effect_counts: { %w[ramp mana_rock] => 8 })
      loads = call(role_weights: { %w[ramp mana_rock] => 0.9 },
                   effect_counts: { %w[ramp mana_rock] => 400 })

      expect(loads[:score]).to eq(enough[:score])
    end

    # "How well is this commander served", not "how many things does it ask for".
    it 'averages its themes rather than summing them' do
      scored = call(role_weights: { %w[ramp mana_rock] => 1.0, %w[removal board_wipe] => 1.0 },
                    effect_counts: { %w[ramp mana_rock] => 8 })

      expect(scored[:score]).to eq(0.5)
    end

    it 'weights a theme the commander is more confident in more heavily' do
      strong = call(role_weights: { %w[ramp mana_rock] => 0.9, %w[removal board_wipe] => 0.7 },
                    effect_counts: { %w[ramp mana_rock] => 8 })
      weak = call(role_weights: { %w[ramp mana_rock] => 0.7, %w[removal board_wipe] => 0.9 },
                  effect_counts: { %w[ramp mana_rock] => 8 })

      expect(strong[:score]).to be > weak[:score]
    end
  end

  describe 'tribal themes' do
    it 'counts owned creatures of a type the commander names' do
      scored = call(subtypes: ['Goblin'], tribe_counts: { 'Goblin' => 8 })

      expect(scored[:score]).to eq(1.0)
    end

    # Worth less than a role the commander is tagged with at 0.9, per CommanderThemes::TRIBAL_WEIGHT.
    it 'pulls less hard than a high-confidence role' do
      mixed = call(role_weights: { %w[ramp mana_rock] => 0.9 }, subtypes: ['Goblin'],
                   effect_counts: { %w[ramp mana_rock] => 8 })

      expect(mixed[:score]).to be > 0.5
    end
  end

  describe 'the matched chips' do
    it 'leads with the best supported theme' do
      scored = call(role_weights: { %w[ramp mana_rock] => 0.9, %w[card_draw draw] => 0.9 },
                    effect_counts: { %w[ramp mana_rock] => 3, %w[card_draw draw] => 30 })

      expect(scored[:matched].first).to eq({ label: 'Draw', owned: 30 })
    end

    it 'leaves out the themes you own nothing for' do
      scored = call(role_weights: { %w[ramp mana_rock] => 0.9, %w[card_draw draw] => 0.9 },
                    effect_counts: { %w[card_draw draw] => 30 })

      expect(scored[:matched].size).to eq(1)
    end

    it 'keeps the list short enough to fit on a card' do
      weights = CardRole::EFFECTS.fetch('manabase').to_h { |effect| [['manabase', effect], 0.9] }
      counts = weights.keys.index_with { 5 }

      expect(call(role_weights: weights, effect_counts: counts)[:matched].size).to eq(3)
    end
  end
end
