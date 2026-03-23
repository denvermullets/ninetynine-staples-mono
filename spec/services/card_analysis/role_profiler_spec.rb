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

  describe 'mill detection' do
    it 'detects mill from mill keyword text' do
      results = profile(
        oracle_text: 'Target opponent mills 3 cards.',
        card_type: 'Sorcery'
      )
      expect(roles_from(results)).to include(%w[mill mill])
    end

    it 'detects mill from put into graveyard text' do
      results = profile(
        oracle_text: 'Target player puts the top 5 cards of their library into their graveyard.',
        card_type: 'Sorcery'
      )
      expect(roles_from(results)).to include(%w[mill mill])
    end

    it 'detects self_mill' do
      results = profile(
        oracle_text: 'Put the top 3 cards of your library into your graveyard.',
        card_type: 'Creature - Zombie'
      )
      expect(roles_from(results)).to include(%w[mill self_mill])
    end

    it 'detects mill_payoff' do
      results = profile(
        oracle_text: 'Whenever an opponent mills one or more cards, you gain 1 life.',
        card_type: 'Enchantment'
      )
      expect(roles_from(results)).to include(%w[mill mill_payoff])
    end

    it 'detects mill keyword at low confidence' do
      results = profile(
        oracle_text: '',
        card_type: 'Creature - Merfolk',
        keywords: ['Mill']
      )
      expect(roles_from(results)).to include(%w[mill mill])
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

  describe 'stax detection' do
    it 'detects tax_effect from cost increase' do
      results = profile(
        oracle_text: 'Noncreature spells cost {2} more to cast.',
        card_type: 'Creature - Human Soldier'
      )
      expect(roles_from(results)).to include(%w[stax tax_effect])
    end

    it 'detects tax_effect from Rhystic Study style' do
      results = profile(
        oracle_text: 'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.',
        card_type: 'Enchantment'
      )
      expect(roles_from(results)).to include(%w[stax tax_effect])
    end

    it 'detects rule_of_law' do
      results = profile(
        oracle_text: "Each player can't cast more than one spell each turn.",
        card_type: 'Enchantment'
      )
      expect(roles_from(results)).to include(%w[stax rule_of_law])
    end

    it 'detects resource_denial' do
      results = profile(
        oracle_text: "Artifacts your opponents control don't untap during their untap steps.",
        card_type: 'Artifact'
      )
      expect(roles_from(results)).to include(%w[stax resource_denial])
    end

    it 'detects static_stax' do
      results = profile(
        oracle_text: "Your opponents can't search libraries.",
        card_type: 'Creature - Human Wizard'
      )
      expect(roles_from(results)).to include(%w[stax static_stax])
    end
  end

  describe 'blink detection' do
    it 'detects flicker from Cloudshift style' do
      results = profile(
        oracle_text: 'Exile target creature you control, then return that card to the battlefield under your control.',
        card_type: 'Instant'
      )
      expect(roles_from(results)).to include(%w[blink flicker])
    end

    it 'detects etb_payoff' do
      results = profile(
        oracle_text: 'Whenever another creature enters the battlefield under your control, draw a card.',
        card_type: 'Creature - Beast'
      )
      expect(roles_from(results)).to include(%w[blink etb_payoff])
    end
  end

  describe 'copy detection' do
    it 'detects clone' do
      results = profile(
        oracle_text: 'You may have Clone enter the battlefield as a copy of any creature on the battlefield.',
        card_type: 'Creature - Shapeshifter'
      )
      expect(roles_from(results)).to include(%w[copy clone])
    end

    it 'detects copy_spell' do
      results = profile(
        oracle_text: 'Copy target instant or sorcery spell. You may choose new targets for the copy.',
        card_type: 'Instant'
      )
      expect(roles_from(results)).to include(%w[copy copy_spell])
    end
  end

  describe 'wheels detection' do
    it 'detects wheel_effect' do
      results = profile(
        oracle_text: 'Each player discards their hand, then draws seven cards.',
        card_type: 'Sorcery'
      )
      expect(roles_from(results)).to include(%w[wheels wheel_effect])
    end
  end

  describe 'graveyard_hate detection' do
    it 'detects exile_graveyard' do
      results = profile(
        oracle_text: "Exile target player's graveyard.",
        card_type: 'Instant'
      )
      expect(roles_from(results)).to include(%w[graveyard_hate exile_graveyard])
    end

    it 'detects graveyard_prevention' do
      results = profile(
        oracle_text: "If a card would be put into an opponent's graveyard from anywhere, exile that card instead.",
        card_type: 'Enchantment'
      )
      expect(roles_from(results)).to include(%w[graveyard_hate graveyard_prevention])
    end
  end

  describe 'group_hug detection' do
    it 'detects group_draw' do
      results = profile(
        oracle_text: 'Each player draws two cards.',
        card_type: 'Sorcery'
      )
      expect(roles_from(results)).to include(%w[group_hug group_draw])
    end

    it 'detects group_ramp' do
      results = profile(
        oracle_text: 'Each player may search their library for a basic land card, ' \
                     'put it onto the battlefield tapped, then shuffle.',
        card_type: 'Sorcery'
      )
      expect(roles_from(results)).to include(%w[group_hug group_ramp])
    end
  end

  describe 'voltron detection' do
    it 'detects double_strike from oracle text' do
      results = profile(
        oracle_text: 'Double strike',
        card_type: 'Creature - Human Knight'
      )
      expect(roles_from(results)).to include(%w[voltron double_strike])
    end

    it 'detects double_strike from keyword' do
      results = profile(
        oracle_text: '',
        card_type: 'Creature - Human Knight',
        keywords: ['Double Strike']
      )
      ds = results.find { |r| r[:role] == 'voltron' && r[:effect] == 'double_strike' }
      expect(ds).to be_present
      expect(ds[:confidence]).to eq(0.5)
      expect(ds[:source]).to eq('keyword')
    end

    it 'detects protection_from' do
      results = profile(
        oracle_text: 'Protection from black and from red',
        card_type: 'Creature - Angel'
      )
      expect(roles_from(results)).to include(%w[voltron protection_from])
    end
  end

  describe 'improved sacrifice detection' do
    it 'detects sacrifice_outlet without colon (broad pattern)' do
      results = profile(
        oracle_text: 'Whenever you sacrifice a creature, create a Food token.',
        card_type: 'Enchantment'
      )
      expect(roles_from(results)).to include(%w[sacrifice sacrifice_outlet])
    end

    it 'detects sacrifice_outlet from additional cost' do
      results = profile(
        oracle_text: 'As an additional cost to cast this spell, sacrifice a creature. Draw two cards.',
        card_type: 'Instant'
      )
      expect(roles_from(results)).to include(%w[sacrifice sacrifice_outlet])
    end

    it 'detects sacrifice_outlet from you may sacrifice' do
      results = profile(
        oracle_text: 'At the beginning of your end step, you may sacrifice a creature. If you do, draw a card.',
        card_type: 'Enchantment'
      )
      expect(roles_from(results)).to include(%w[sacrifice sacrifice_outlet])
    end

    it 'detects aristocrat_payoff from whenever is sacrificed' do
      results = profile(
        oracle_text: 'Whenever an artifact is sacrificed, you gain 1 life.',
        card_type: 'Creature - Human Artificer'
      )
      expect(roles_from(results)).to include(%w[sacrifice aristocrat_payoff])
    end
  end

  describe 'manabase detection' do
    it 'detects fetch_land' do
      results = profile(
        oracle_text: '{T}, Pay 1 life, Sacrifice Polluted Delta: Search your library ' \
                     'for an island or swamp card, put it onto the battlefield, then shuffle.',
        card_type: 'Land'
      )
      expect(roles_from(results)).to include(%w[manabase fetch_land])
    end

    it 'detects shock_land' do
      results = profile(
        oracle_text: 'As Watery Grave enters the battlefield, you may pay 2 life. ' \
                     "If you don't, it enters the battlefield tapped. {T}: Add {U} or {B}.",
        card_type: 'Land - Island Swamp'
      )
      expect(roles_from(results)).to include(%w[manabase shock_land])
    end

    it 'detects pain_land' do
      results = profile(
        oracle_text: '{T}: Add {C}. {T}: Add {W} or {B}. Underground River deals 1 damage to you.',
        card_type: 'Land'
      )
      expect(roles_from(results)).to include(%w[manabase pain_land])
    end

    it 'detects check_land' do
      results = profile(
        oracle_text: 'Drowned Catacomb enters the battlefield tapped unless you control ' \
                     'an island or a swamp. {T}: Add {U} or {B}.',
        card_type: 'Land'
      )
      expect(roles_from(results)).to include(%w[manabase check_land])
    end

    it 'detects bounce_land' do
      results = profile(
        oracle_text: 'Dimir Aqueduct enters the battlefield tapped. When it enters, ' \
                     "return a land you control to its owner's hand. {T}: Add {U}{B}.",
        card_type: 'Land'
      )
      expect(roles_from(results)).to include(%w[manabase bounce_land])
    end

    it 'detects utility_land' do
      results = profile(
        oracle_text: '{T}: Add {C}. {2}, {T}: Draw a card.',
        card_type: 'Land'
      )
      expect(roles_from(results)).to include(%w[manabase utility_land])
    end

    it 'detects tri_land' do
      results = profile(
        oracle_text: '{T}: Add {W}, {U}, or {B}.',
        card_type: 'Land'
      )
      expect(roles_from(results)).to include(%w[manabase tri_land])
    end

    it 'detects generic dual_land' do
      results = profile(
        oracle_text: '{T}: Add {G} or {U}.',
        card_type: 'Land'
      )
      expect(roles_from(results)).to include(%w[manabase dual_land])
    end

    it 'detects any_color_land from Command Tower style' do
      results = profile(
        oracle_text: "{T}: Add one mana of any color in your commander's color identity.",
        card_type: 'Land'
      )
      expect(roles_from(results)).to include(%w[manabase any_color_land])
    end

    it 'detects any_color_land with mana_confluence when life cost' do
      results = profile(
        oracle_text: '{T}, Pay 1 life: Add one mana of any color.',
        card_type: 'Land'
      )
      expect(roles_from(results)).to include(%w[manabase any_color_land])
      expect(roles_from(results)).to include(%w[manabase mana_confluence])
    end

    it 'detects mana_producer as fallback for Cabal Coffers style' do
      results = profile(
        oracle_text: '{2}, {T}: Add {B} for each Swamp you control.',
        card_type: 'Land'
      )
      expect(roles_from(results)).to include(%w[manabase mana_producer])
    end

    it 'detects mana_producer for Reliquary Tower style' do
      results = profile(
        oracle_text: "You have no maximum hand size.\n{T}: Add {C}.",
        card_type: 'Land'
      )
      expect(roles_from(results)).to include(%w[manabase mana_producer])
    end

    it 'does not detect manabase for non-land cards' do
      results = profile(
        oracle_text: '{T}: Add {G} or {U}.',
        card_type: 'Artifact'
      )
      manabase = results.select { |r| r[:role] == 'manabase' }
      expect(manabase).to be_empty
    end

    it 'detects dual_land from subtypes' do
      results = profile(
        oracle_text: '{T}: Add {U} or {B}.',
        card_type: 'Land - Island Swamp',
        subtypes: %w[Island Swamp]
      )
      dual = results.find { |r| r[:role] == 'manabase' && r[:effect] == 'dual_land' && r[:source] == 'subtype' }
      expect(dual).to be_present
      expect(dual[:confidence]).to eq(0.9)
    end

    it 'detects basic_land from subtypes and type' do
      results = profile(
        oracle_text: '{T}: Add {G}.',
        card_type: 'Basic Land - Forest',
        subtypes: %w[Forest]
      )
      expect(roles_from(results)).to include(%w[manabase basic_land])
    end

    it 'detects mdfc_land from layout' do
      results = profile(
        oracle_text: '{T}: Add {B}.',
        card_type: 'Land',
        layout: 'modal_dfc'
      )
      expect(roles_from(results)).to include(%w[manabase mdfc_land])
    end
  end

  describe 'multi-role overlap' do
    it 'wheel cards get both wheels and group_hug roles' do
      results = profile(
        oracle_text: 'Each player discards their hand, then draws seven cards.',
        card_type: 'Sorcery'
      )
      expect(roles_from(results)).to include(%w[wheels wheel_effect])
      expect(roles_from(results)).to include(%w[group_hug group_draw])
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
