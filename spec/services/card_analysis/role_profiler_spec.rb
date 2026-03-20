require 'rails_helper'

RSpec.describe CardAnalysis::RoleProfiler, type: :service do
  let(:oracle_id) { SecureRandom.uuid }

  def profile(oracle_text: '', card_type: '', **)
    described_class.call(
      scryfall_oracle_id: oracle_id,
      oracle_text: oracle_text,
      card_type: card_type,
      **
    )
  end

  def roles_from(results)
    results.map { |r| [r[:role], r[:effect]] }
  end

  describe 'ramp detection' do
    it 'detects land_ramp from Cultivate-style text' do
      results = profile(
        oracle_text: 'Search your library for a basic land card, ' \
                     'put that card onto the battlefield tapped, then shuffle.',
        card_type: 'Sorcery'
      )
      expect(roles_from(results)).to include(%w[ramp land_ramp])
    end

    it 'detects mana_dork from creature with tap for mana' do
      results = profile(
        oracle_text: '{T}: Add {G}.',
        card_type: 'Creature - Elf Druid'
      )
      expect(roles_from(results)).to include(%w[ramp mana_dork])
    end

    it 'detects mana_rock from artifact with tap for mana' do
      results = profile(
        oracle_text: '{T}: Add {C}.',
        card_type: 'Artifact'
      )
      expect(roles_from(results)).to include(%w[ramp mana_rock])
    end

    it 'detects cost_reduction' do
      results = profile(
        oracle_text: 'Creature spells you cast cost {1} less to cast.',
        card_type: 'Creature - Human Wizard'
      )
      expect(roles_from(results)).to include(%w[ramp cost_reduction])
    end
  end

  describe 'removal detection' do
    it 'detects targeted_removal' do
      results = profile(
        oracle_text: 'Destroy target creature.',
        card_type: 'Instant'
      )
      expect(roles_from(results)).to include(%w[removal targeted_removal])
    end

    it 'detects board_wipe' do
      results = profile(
        oracle_text: 'Destroy all creatures.',
        card_type: 'Sorcery'
      )
      expect(roles_from(results)).to include(%w[removal board_wipe])
    end

    it 'detects exile_removal' do
      results = profile(
        oracle_text: 'Exile target creature.',
        card_type: 'Instant'
      )
      expect(roles_from(results)).to include(%w[removal exile_removal])
    end

    it 'detects bounce' do
      results = profile(
        oracle_text: "Return target creature to its owner's hand.",
        card_type: 'Instant'
      )
      expect(roles_from(results)).to include(%w[removal bounce])
    end
  end

  describe 'card_draw detection' do
    it 'detects draw' do
      results = profile(
        oracle_text: 'Draw two cards.',
        card_type: 'Instant'
      )
      expect(roles_from(results)).to include(%w[card_draw draw])
    end

    it 'detects impulse_draw' do
      results = profile(
        oracle_text: 'Exile the top two cards of your library. You may play them this turn.',
        card_type: 'Sorcery'
      )
      expect(roles_from(results)).to include(%w[card_draw impulse_draw])
    end

    it 'detects loot' do
      results = profile(
        oracle_text: 'Draw a card, then discard a card.',
        card_type: 'Instant'
      )
      expect(roles_from(results)).to include(%w[card_draw loot])
    end
  end

  describe 'tutor detection' do
    it 'detects tutor_to_hand' do
      results = profile(
        oracle_text: 'Search your library for a card, put it into your hand, then shuffle.',
        card_type: 'Sorcery'
      )
      expect(roles_from(results)).to include(%w[tutor tutor_to_hand])
    end

    it 'detects tutor_to_top' do
      results = profile(
        oracle_text: 'Search your library for a card, put it on top of your library, then shuffle.',
        card_type: 'Sorcery'
      )
      expect(roles_from(results)).to include(%w[tutor tutor_to_top])
    end
  end

  describe 'protection detection' do
    it 'detects counterspell' do
      results = profile(
        oracle_text: 'Counter target spell.',
        card_type: 'Instant'
      )
      expect(roles_from(results)).to include(%w[protection counterspell])
    end
  end

  describe 'recursion detection' do
    it 'detects reanimate' do
      results = profile(
        oracle_text: 'Return target creature card from your graveyard to the battlefield.',
        card_type: 'Sorcery'
      )
      expect(roles_from(results)).to include(%w[recursion reanimate])
    end
  end

  describe 'tokens detection' do
    it 'detects token_creation' do
      results = profile(
        oracle_text: 'Create three 1/1 white Soldier creature tokens.',
        card_type: 'Sorcery'
      )
      expect(roles_from(results)).to include(%w[tokens token_creation])
    end
  end

  describe 'finisher detection' do
    it 'detects extra_turns' do
      results = profile(
        oracle_text: 'Take an extra turn after this one.',
        card_type: 'Sorcery'
      )
      expect(roles_from(results)).to include(%w[finisher extra_turns])
    end

    it 'detects alt_wincon' do
      results = profile(
        oracle_text: 'If you have 40 or more life, you win the game.',
        card_type: 'Enchantment'
      )
      expect(roles_from(results)).to include(%w[finisher alt_wincon])
    end

    it 'detects big_beater from type line' do
      results = profile(
        oracle_text: 'Trample',
        card_type: 'Creature - Dinosaur',
        power: 7
      )
      expect(roles_from(results)).to include(%w[finisher big_beater])
    end
  end

  describe 'lands_matter detection' do
    it 'detects extra_land_drop' do
      results = profile(
        oracle_text: 'You may play an additional land on each of your turns.',
        card_type: 'Creature - Snake'
      )
      expect(roles_from(results)).to include(%w[lands_matter extra_land_drop])
    end

    it 'detects landfall_payoff' do
      results = profile(
        oracle_text: 'Landfall - Whenever a land enters the battlefield under your control, ' \
                     'put a +1/+1 counter on this.',
        card_type: 'Creature - Plant'
      )
      expect(roles_from(results)).to include(%w[lands_matter landfall_payoff])
    end
  end

  describe 'sacrifice detection' do
    it 'detects sacrifice_outlet' do
      results = profile(
        oracle_text: 'Sacrifice a creature: Draw a card.',
        card_type: 'Enchantment'
      )
      expect(roles_from(results)).to include(%w[sacrifice sacrifice_outlet])
    end

    it 'detects death_trigger' do
      results = profile(
        oracle_text: 'Whenever another creature you control dies, ' \
                     'create a 1/1 black Spirit creature token with flying.',
        card_type: 'Creature - Human Aristocrat'
      )
      expect(roles_from(results)).to include(%w[sacrifice death_trigger])
    end
  end

  describe 'keyword detection' do
    it 'detects flying keyword at low confidence' do
      results = profile(
        oracle_text: '',
        card_type: 'Creature - Angel',
        keywords: ['Flying']
      )
      flying = results.find { |r| r[:role] == 'evasion' && r[:effect] == 'flying_grant' }
      expect(flying).to be_present
      expect(flying[:confidence]).to eq(0.4)
      expect(flying[:source]).to eq('keyword')
    end

    it 'detects lifelink keyword' do
      results = profile(
        oracle_text: '',
        card_type: 'Creature - Angel',
        keywords: ['Lifelink']
      )
      expect(roles_from(results)).to include(%w[lifegain life_gain])
    end
  end

  describe 'type-line detection' do
    it 'detects equipment' do
      results = profile(
        oracle_text: 'Equipped creature gets +2/+2. Equip {2}',
        card_type: 'Artifact - Equipment'
      )
      expect(roles_from(results)).to include(%w[pump equipment])
    end

    it 'detects aura_buff' do
      results = profile(
        oracle_text: 'Enchant creature. Enchanted creature gets +3/+3.',
        card_type: 'Enchantment - Aura'
      )
      expect(roles_from(results)).to include(%w[pump aura_buff])
    end
  end

  describe 'confidence merging' do
    it 'keeps highest confidence when multiple sources detect same role/effect' do
      results = profile(
        oracle_text: 'Hexproof',
        card_type: 'Creature - Troll',
        keywords: ['Hexproof']
      )
      hexproof = results.find { |r| r[:role] == 'protection' && r[:effect] == 'hexproof_grant' }
      expect(hexproof[:confidence]).to eq(0.75) # pattern > keyword
    end
  end

  describe 'edge cases' do
    it 'returns empty array for vanilla creature' do
      results = profile(
        oracle_text: '',
        card_type: 'Creature - Bear',
        power: 2
      )
      expect(results).to eq([])
    end

    it 'handles nil oracle_text' do
      results = profile(
        oracle_text: nil,
        card_type: 'Land'
      )
      expect(results).to be_an(Array)
    end
  end
end
