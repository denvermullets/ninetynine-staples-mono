module CommanderSpellbook
  class SyncDeckCombos < Service
    def initialize(collection:)
      @collection = collection
    end

    def call
      card_names = load_card_names
      commander_names = load_commander_names
      log "#{card_names.size} unique cards, #{commander_names.size} commanders"

      result = FindCombos.call(card_names: card_names, commanders: commander_names)
      return log_and_return_error(result) if result[:error]

      save_combos(result)
      log "Saved #{@collection.deck_combos.count} deck_combos"
      { success: true }
    end

    private

    def log(message) = Rails.logger.info("[SyncDeckCombos] #{message}")

    def log_and_return_error(result)
      log "FindCombos returned error: #{result[:error]}"
      result
    end

    def save_combos(result)
      ActiveRecord::Base.transaction do
        @collection.deck_combos.destroy_all
        process_combos(result[:included], 'included')
        process_combos(result[:almost_included], 'almost_included')
        @collection.update!(combos_checked_at: Time.current)
      end
    end

    def load_card_names
      @collection.collection_magic_cards
                 .includes(:magic_card)
                 .map { |cmc| cmc.magic_card.name }
                 .uniq
    end

    def load_commander_names
      @collection.commanders
                 .map { |cmc| cmc.magic_card.name }
    end

    def process_combos(combos, combo_type)
      combos.each do |combo_data|
        next if combo_data[:spellbook_id].blank?

        combo = find_or_create_combo(combo_data)
        sync_combo_cards(combo, combo_data[:cards])

        deck_combo = @collection.deck_combos.create!(combo: combo, combo_type: combo_type)
        create_missing_cards(deck_combo, combo_data[:missing_cards]) if combo_type == 'almost_included'
      end
    end

    def find_or_create_combo(data)
      combo = Combo.find_or_initialize_by(spellbook_id: data[:spellbook_id])
      combo.update!(
        prerequisites: data[:prerequisites], steps: data[:steps], results: data[:results],
        color_identity: data[:color_identity], permalink: data[:permalink], has_banned_card: data[:has_banned_card]
      )
      combo
    end

    def sync_combo_cards(combo, cards)
      combo.combo_cards.destroy_all
      cards&.each do |card|
        combo.combo_cards.create!(card_name: card[:name], oracle_id: card[:oracle_id])
      end
    end

    def create_missing_cards(deck_combo, missing_cards)
      missing_cards&.each do |missing|
        deck_combo.deck_combo_missing_cards.create!(card_name: missing[:name], oracle_id: missing[:oracle_id])
      end
    end
  end
end
