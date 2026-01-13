module DeckBuilder
  class Finalize < Service
    class InsufficientCardsError < StandardError; end

    def initialize(deck:)
      @deck = deck
      @cards_moved = 0
      @cards_needed = 0
    end

    def call
      return error_result('No staged cards to finalize') unless @deck.in_build_mode?

      ActiveRecord::Base.transaction do
        validate_all_sources_available!
        process_staged_cards
        update_collection_totals(@deck)
      end
      { success: true, cards_moved: @cards_moved, cards_needed: @cards_needed }
    rescue InsufficientCardsError => e
      error_result(e.message)
    end

    private

    def error_result(message) = { success: false, error: message }

    def staged_cards = @deck.collection_magic_cards.staged.includes(:magic_card, :source_collection)

    def process_staged_cards
      staged_cards.find_each do |card|
        card.from_owned_collection? ? process_owned_card(card) : process_planned_card(card)
      end
    end

    def process_owned_card(card)
      move_from_source(card)
      @cards_moved += card.total_staged
    end

    def process_planned_card(card)
      finalize_deck_card(card, needed: true)
      @cards_needed += card.total_staged
    end

    def validate_all_sources_available!
      staged_cards.from_collection.find_each { |staged| validate_single_source(staged) }
    end

    def validate_single_source(staged)
      source = find_source_card(staged)
      raise InsufficientCardsError, "#{staged.magic_card.name} is no longer in source collection" unless source

      validate_quantities(staged, source)
    end

    def find_source_card(staged)
      CollectionMagicCard.find_by(
        collection_id: staged.source_collection_id, magic_card_id: staged.magic_card_id, staged: false, needed: false
      )
    end

    def validate_quantities(staged, source)
      avail = source.quantity + (source.proxy_quantity || 0)
      foil_avail = source.foil_quantity + (source.proxy_foil_quantity || 0)
      name = staged.magic_card.name
      raise InsufficientCardsError, "Only #{avail} of #{name} available" if staged.staged_quantity > avail

      return unless staged.staged_foil_quantity > foil_avail

      raise InsufficientCardsError,
            "Only #{foil_avail} foil #{name} available"
    end

    def move_from_source(staged_card)
      source = CollectionMagicCard.find_by!(
        collection_id: staged_card.source_collection_id, magic_card_id: staged_card.magic_card_id,
        staged: false, needed: false
      )
      reduce_source(source, staged_card)
      finalize_deck_card(staged_card, needed: false)
      update_collection_totals(source.collection)
    end

    def reduce_source(source, staged_card)
      reductions = calculate_reductions(source, staged_card)

      if source_empty_after_reduction?(source, reductions)
        source.destroy!
      else
        source.update!(reductions)
      end
    end

    def calculate_reductions(source, staged_card)
      reg = [staged_card.staged_quantity, source.quantity].min
      foil_reg = [staged_card.staged_foil_quantity, source.foil_quantity].min
      { quantity: source.quantity - reg, foil_quantity: source.foil_quantity - foil_reg,
        proxy_quantity: (source.proxy_quantity || 0) - (staged_card.staged_quantity - reg),
        proxy_foil_quantity: (source.proxy_foil_quantity || 0) - (staged_card.staged_foil_quantity - foil_reg) }
    end

    def source_empty_after_reduction?(_source, reductions) = reductions.values.all?(&:zero?)

    def finalize_deck_card(staged_card, needed:)
      staged_card.update!(
        staged: false, needed: needed, quantity: staged_card.staged_quantity,
        foil_quantity: staged_card.staged_foil_quantity, staged_quantity: 0, staged_foil_quantity: 0,
        source_collection_id: nil
      )
    end

    def update_collection_totals(collection)
      owned_cards = collection.collection_magic_cards.finalized.owned
      total_value = owned_cards.sum do |c|
        (c.quantity * c.magic_card.normal_price.to_f) + (c.foil_quantity * c.magic_card.foil_price.to_f)
      end
      collection.update!(total_quantity: owned_cards.sum(:quantity),
                         total_foil_quantity: owned_cards.sum(:foil_quantity), total_value: total_value)
    end
  end
end
