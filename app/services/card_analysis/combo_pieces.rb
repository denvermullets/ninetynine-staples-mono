module CardAnalysis
  # The combo direction: which single cards would finish a combo this deck is already one card away from?
  #
  # Read off the deck's last Commander Spellbook check rather than asked of Spellbook here. find-my-combos
  # already answers exactly this question for the whole deck at once - its almostIncluded combos are in
  # the commander's identity and missing one card - and SyncDeckCombos keeps that card in
  # deck_combo_missing_cards. Asking per card instead would only ever find two-card combos.
  class ComboPieces < Service
    def initialize(deck:, exclude_oracle_ids: [])
      @deck = deck
      @exclude_oracle_ids = exclude_oracle_ids
    end

    # -> { oracle_id => { combo_count:, combo_results: [...] } }
    def call
      rows.group_by(&:first).transform_values do |pairs|
        results = pairs.map(&:last)
        { combo_count: results.size, combo_results: results.compact_blank.uniq }
      end
    end

    private

    # A banned combo is not a suggestion, and a deck_combo missing two cards is not "one card away" - the
    # finder tolerates those, so they are filtered here rather than trusted.
    def rows
      DeckComboMissingCard
        .joins(deck_combo: :combo)
        .where(deck_combos: { collection_id: @deck.id, combo_type: 'almost_included' })
        .where(combos: { has_banned_card: [false, nil] })
        .where(deck_combo_id: single_missing_deck_combo_ids)
        .where.not(oracle_id: nil)
        .where.not(oracle_id: @exclude_oracle_ids.to_a)
        .order(:id)
        .pluck(:oracle_id, 'combos.results')
    end

    def single_missing_deck_combo_ids
      DeckComboMissingCard.group(:deck_combo_id).having('COUNT(*) = 1').select(:deck_combo_id)
    end
  end
end
