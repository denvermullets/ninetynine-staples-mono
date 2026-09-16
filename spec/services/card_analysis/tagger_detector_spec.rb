require 'rails_helper'

RSpec.describe CardAnalysis::TaggerDetector, type: :service do
  describe '.roles_for' do
    it 'maps a tag slug to its role and effect' do
      expect(described_class.roles_for(%w[spot-removal])).to eq([%w[removal targeted_removal]])
    end

    it 'ignores slugs with no mapping' do
      expect(described_class.roles_for(%w[alliteration removal])).to be_empty
    end

    it 'collapses slugs that map to the same effect' do
      expect(described_class.roles_for(%w[loot rummage])).to eq([%w[card_draw loot]])
    end
  end

  # CommanderSynergy only baselines effects listed in CardRole::EFFECTS, so a typo here would silently
  # drop that effect out of every suggestion
  it 'only maps to roles and effects CardRole knows' do
    described_class::TAG_ROLES.each do |slug, (role, effect)|
      expect(CardRole::ROLES).to include(role), "#{slug} maps to unknown role #{role}"
      expect(CardRole::EFFECTS.fetch(role)).to include(effect), "#{slug} maps to unknown effect #{role}/#{effect}"
    end
  end

  describe 'inside RoleProfiler' do
    def profile(tag_slugs:, text: 'Destroy target creature.')
      CardAnalysis::RoleProfiler.call(scryfall_oracle_id: SecureRandom.uuid, oracle_text: text,
                                      card_type: 'Instant', tag_slugs: tag_slugs)
    end

    it 'outranks a pattern rule for the same effect' do
      removal = profile(tag_slugs: %w[spot-removal]).find { |row| row[:effect] == 'targeted_removal' }

      expect(removal).to include(confidence: 1.0, source: 'tagger')
    end

    it 'adds effects the pattern rules cannot see' do
      rows = profile(tag_slugs: %w[repeatable-proliferate], text: 'Proliferate.')

      expect(rows).to include(hash_including(role: 'counters', effect: 'proliferate', source: 'tagger'))
    end

    it 'leaves pattern rows alone when a card has no tags' do
      removal = profile(tag_slugs: []).find { |row| row[:effect] == 'targeted_removal' }

      expect(removal[:source]).to eq('pattern')
    end
  end
end
