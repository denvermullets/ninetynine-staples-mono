module DeckBuilder
  class LoadCombos < Service
    COMBO_ORDER = Arel.sql("CASE combo_type WHEN 'included' THEN 0 ELSE 1 END")

    def self.combos_for_card(deck:, oracle_id:)
      deck.deck_combos
          .includes(combo: :combo_cards, deck_combo_missing_cards: [])
          .joins(combo: :combo_cards)
          .where(combo_cards: { oracle_id: oracle_id })
          .distinct
    end

    def self.combos_for_page(deck:, oracle_id: nil)
      if oracle_id.present?
        matching_ids = deck.deck_combos.joins(combo: :combo_cards)
                           .where(combo_cards: { oracle_id: oracle_id }).select(:id)
        scope = DeckCombo.where(id: matching_ids)
      else
        scope = deck.deck_combos
      end

      scope.includes(combo: :combo_cards, deck_combo_missing_cards: [])
           .order(COMBO_ORDER, :id)
    end

    def initialize(deck:)
      @deck = deck
    end

    def call
      deck_combos = @deck.deck_combos
                         .includes(combo: :combo_cards, deck_combo_missing_cards: [])
                         .to_a

      {
        combo_card_oracle_ids: build_oracle_id_map(deck_combos),
        combos_by_oracle_id: build_combos_by_oracle_id(deck_combos),
        checked_at: @deck.combos_checked_at
      }
    end

    private

    def build_oracle_id_map(deck_combos)
      map = {}

      deck_combos.each do |dc|
        dc.combo.combo_cards.each do |cc|
          next if cc.oracle_id.blank?

          existing = map[cc.oracle_id]
          # :included takes priority over :almost_included
          if existing.nil? || (dc.combo_type == 'included' && existing == :almost_included)
            map[cc.oracle_id] = dc.combo_type.to_sym
          end
        end
      end

      map
    end

    def build_combos_by_oracle_id(deck_combos)
      map = Hash.new { |h, k| h[k] = [] }

      deck_combos.each do |dc|
        dc.combo.combo_cards.each do |cc|
          next if cc.oracle_id.blank?

          map[cc.oracle_id] << dc
        end
      end

      map
    end
  end
end
