class CardRole < ApplicationRecord
  ROLES = %w[
    ramp removal card_draw tutor protection recursion tokens
    lifegain pump evasion finisher lands_matter sacrifice mill
    manabase stax blink copy wheels graveyard_hate group_hug voltron
  ].freeze

  EFFECTS = {
    'ramp' => %w[land_ramp mana_dork mana_rock ritual cost_reduction],
    'removal' => %w[targeted_removal board_wipe exile_removal sacrifice_removal bounce],
    'card_draw' => %w[draw impulse_draw loot cantrip card_selection],
    'tutor' => %w[tutor_to_hand tutor_to_top tutor_to_battlefield],
    'protection' => %w[counterspell hexproof_grant indestructible_grant ward_grant phase_out],
    'recursion' => %w[graveyard_to_hand graveyard_to_battlefield reanimate],
    'tokens' => %w[token_creation token_anthem populate],
    'lifegain' => %w[life_gain life_drain lifegain_payoff],
    'pump' => %w[combat_trick anthem equipment aura_buff],
    'evasion' => %w[flying_grant unblockable trample_grant menace_grant],
    'finisher' => %w[extra_turns alt_wincon big_beater],
    'lands_matter' => %w[extra_land_drop landfall_payoff land_recursion land_animation],
    'sacrifice' => %w[sacrifice_outlet death_trigger aristocrat_payoff],
    'mill' => %w[mill self_mill mill_payoff],
    'manabase' => %w[dual_land fetch_land shock_land pain_land check_land filter_land bounce_land
                     utility_land tri_land mana_confluence basic_land mdfc_land any_color_land
                     mana_producer],
    'stax' => %w[tax_effect resource_denial static_stax rule_of_law],
    'blink' => %w[flicker etb_payoff blink_repeatable],
    'copy' => %w[clone copy_spell],
    'wheels' => %w[wheel_effect windfall_effect],
    'graveyard_hate' => %w[exile_graveyard graveyard_prevention],
    'group_hug' => %w[group_draw group_ramp group_lifegain],
    'voltron' => %w[double_strike protection_from]
  }.freeze

  validates :scryfall_oracle_id, presence: true
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :effect, presence: true
  validates :confidence, presence: true, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
  validates :scryfall_oracle_id, uniqueness: { scope: %i[role effect] }

  scope :for_oracle_id, ->(oid) { where(scryfall_oracle_id: oid) }
  scope :for_role, ->(role) { where(role: role) }
  scope :high_confidence, -> { where('confidence >= ?', 0.7) }
end
