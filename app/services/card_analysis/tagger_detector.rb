# Maps Scryfall Tagger oracle tags onto the card_roles vocabulary.
#
# Input is a card's expanded slug set: its direct taggings plus every ancestor of those tags, so a card
# tagged doom-blade also carries spot-removal. A key therefore matches the tag and everything under it, and
# keys are chosen where the whole subtree is true for the effect. Umbrellas that mix effects are not keys:
#   - removal / removal-creature: 885 of the 981 sweepers sit under removal-creature, so keying it would
#     call Wrath of God targeted removal. spot-removal and sweeper are keyed instead.
#   - tutor: its tutor-to-battlefield branch is mostly Rampant Growth-style land ramp, and would swamp the
#     tutor DeckTarget of 3. tutor-to-hand and tutor-to-top are keyed instead.
#   - restock puts cards back into the library, which is neither recursion effect.
#   - repeatable-token-generator includes Treasure and Clue makers; only creature tokens are keyed.
#
# Confidence is 1.0 and RoleProfiler runs this before its own rules. A curated tag is a person's claim that
# the card does the thing, not a guess from a regex, so it has to win: every add_result in the profiler
# only replaces a row on strictly higher confidence, so going first at 1.0 means no rule can displace it.
#
# Every role and effect here must exist in CardRole::ROLES / CardRole::EFFECTS - CommanderSynergy only
# baselines effects listed there. spec/services/card_analysis/tagger_detector_spec.rb enforces it.
module CardAnalysis
  class TaggerDetector
    CONFIDENCE = 1.0
    SOURCE = 'tagger'.freeze

    def self.expand(mapping)
      mapping.flat_map { |slugs, role_effect| Array(slugs).map { |slug| [slug, role_effect.freeze] } }.to_h
    end

    TAG_ROLES = expand(
      'land-ramp' => %w[ramp land_ramp],
      'mana-dork' => %w[ramp mana_dork],
      'mana-rock' => %w[ramp mana_rock],
      'ritual' => %w[ramp ritual],
      'cost-reducer' => %w[ramp cost_reduction],

      'spot-removal' => %w[removal targeted_removal],
      'sweeper' => %w[removal board_wipe],
      'removal-exile' => %w[removal exile_removal],
      'removal-sacrifice' => %w[removal sacrifice_removal],
      'removal-bounce' => %w[removal bounce],

      %w[pure-draw repeatable-draw burst-draw] => %w[card_draw draw],
      'cantrip' => %w[card_draw cantrip],
      %w[loot rummage] => %w[card_draw loot],
      %w[impulse impulsive-draw] => %w[card_draw impulse_draw],
      %w[brainstorm scry surveil] => %w[card_draw card_selection],

      'tutor-to-hand' => %w[tutor tutor_to_hand],
      'tutor-to-top' => %w[tutor tutor_to_top],

      'counterspell' => %w[protection counterspell],
      %w[gives-hexproof gains-hexproof gives-player-hexproof gives-shroud
         gives-player-shroud] => %w[protection hexproof_grant],
      %w[gives-indestructible gains-indestructible] => %w[protection indestructible_grant],
      'gives-ward' => %w[protection ward_grant],
      'gives-protection' => %w[voltron protection_from],

      'reanimate' => %w[recursion reanimate],
      'regrowth' => %w[recursion graveyard_to_hand],
      'recursion-land' => %w[lands_matter land_recursion],

      %w[repeatable-creature-tokens token-increaser] => %w[tokens token_creation],

      'lifegain' => %w[lifegain life_gain],
      %w[drain-life drain-creature] => %w[lifegain life_drain],

      'combat-trick' => %w[pump combat_trick],
      'anthem' => %w[pump anthem],

      %w[unblockable gives-unblockable] => %w[evasion unblockable],
      %w[gives-flying gains-flying] => %w[evasion flying_grant],
      'gives-trample' => %w[evasion trample_grant],
      %w[gives-menace super-menace] => %w[evasion menace_grant],
      %w[gives-double-strike gains-double-strike] => %w[voltron double_strike],

      'extra-turn' => %w[finisher extra_turns],
      'alternate-win-condition' => %w[finisher alt_wincon],

      'landfall' => %w[lands_matter landfall_payoff],
      'extra-land' => %w[lands_matter extra_land_drop],
      'animate-land' => %w[lands_matter land_animation],

      'sacrifice-outlet' => %w[sacrifice sacrifice_outlet],
      'death-trigger' => %w[sacrifice death_trigger],
      'blood-artist-ability' => %w[sacrifice aristocrat_payoff],

      'mill-self' => %w[mill self_mill],
      %w[mill-opponent mill-any] => %w[mill mill],
      'synergy-mill' => %w[mill mill_payoff],

      %w[tax pillowfort] => %w[stax tax_effect],
      'hatebear' => %w[stax static_stax],
      'mass-land-denial' => %w[stax resource_denial],
      'rule-of-law' => %w[stax rule_of_law],

      'flicker' => %w[blink flicker],
      %w[clone copy-creature] => %w[copy clone],
      %w[copy-spell copy-instant copy-sorcery] => %w[copy copy_spell],
      'wheel' => %w[wheels wheel_effect],
      %w[sweeper-graveyard hate-graveyard] => %w[graveyard_hate exile_graveyard],
      'group-hug' => %w[group_hug group_draw],

      %w[repeatable-proliferate pseudo-proliferate synergy-proliferate] => %w[counters proliferate],
      'counters-matter' => %w[counters counters_matter],
      %w[gives-pp-counters repeatable-pp-counters] => %w[counters plus_one_counters]
    ).freeze

    # -> [[role, effect], ...] for the slugs this card carries
    def self.roles_for(tag_slugs)
      TAG_ROLES.slice(*tag_slugs).values.uniq
    end
  end
end
