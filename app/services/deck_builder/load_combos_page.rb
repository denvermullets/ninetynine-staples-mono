module DeckBuilder
  class LoadCombosPage < Service
    COMBO_ORDER = Arel.sql("CASE combo_type WHEN 'included' THEN 0 ELSE 1 END")

    def initialize(deck:, oracle_id: nil)
      @deck = deck
      @oracle_id = oracle_id
    end

    def call
      scope = if @oracle_id.present?
                matching_ids = @deck.deck_combos.joins(combo: :combo_cards)
                                    .where(combo_cards: { oracle_id: @oracle_id }).select(:id)
                DeckCombo.where(id: matching_ids)
              else
                @deck.deck_combos
              end

      scope.includes(combo: :combo_cards, deck_combo_missing_cards: [])
           .order(COMBO_ORDER, :id)
    end
  end
end
