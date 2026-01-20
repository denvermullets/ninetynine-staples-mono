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
        Collections::UpdateTotals.call(collection: @deck)
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
      # Planned cards stay staged - don't finalize them
      # Just count them for the summary
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
      name = staged.magic_card.name

      validations = [
        [staged.staged_quantity, source.quantity, 'regular'],
        [staged.staged_foil_quantity, source.foil_quantity, 'foil'],
        [staged.staged_proxy_quantity, source.proxy_quantity || 0, 'proxy'],
        [staged.staged_proxy_foil_quantity, source.proxy_foil_quantity || 0, 'foil proxy']
      ]

      validations.each do |needed, available, type|
        raise InsufficientCardsError, "Only #{available} #{type} #{name} available" if needed > available
      end
    end

    def move_from_source(staged_card)
      source = CollectionMagicCard.find_by!(
        collection_id: staged_card.source_collection_id, magic_card_id: staged_card.magic_card_id,
        staged: false, needed: false
      )
      reduce_source(source, staged_card)
      finalize_deck_card(staged_card)
      Collections::UpdateTotals.call(collection: source.collection)
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
      {
        quantity: source.quantity - staged_card.staged_quantity,
        foil_quantity: source.foil_quantity - staged_card.staged_foil_quantity,
        proxy_quantity: (source.proxy_quantity || 0) - staged_card.staged_proxy_quantity,
        proxy_foil_quantity: (source.proxy_foil_quantity || 0) - staged_card.staged_proxy_foil_quantity
      }
    end

    def source_empty_after_reduction?(_source, reductions) = reductions.values.all?(&:zero?)

    def finalize_deck_card(staged_card)
      staged_card.update!(
        staged: false,
        needed: false,
        quantity: staged_card.staged_quantity,
        foil_quantity: staged_card.staged_foil_quantity,
        proxy_quantity: staged_card.staged_proxy_quantity,
        proxy_foil_quantity: staged_card.staged_proxy_foil_quantity,
        staged_quantity: 0,
        staged_foil_quantity: 0,
        staged_proxy_quantity: 0,
        staged_proxy_foil_quantity: 0,
        source_collection_id: nil
      )
    end
  end
end
