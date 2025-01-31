# this service will take in a collection of cards
# searches and sorts the collection

module Search
  class Collection < Service
    def initialize(collection:, search_term:, code:, sort_by:)
      @collection_cards = collection&.magic_cards || []
      @collection = collection || []
      @search_term = search_term
      @boxset_id = code.nil? ? nil : Boxset.find_by(code: code)&.id
      @sort_by = sort_by
    end

    def call
      return [] if @collection_cards&.empty? && @search_term&.empty?

      case @sort_by
      when :id
        sort_by_card_num(query_cards)
      when :price
        sort_by_price(query_cards)
      end
    end

    private

    def query_cards
      if @collection_cards.blank? && @search_term.present?
        # only on boxset view will this be hit, collections view currently always has a lookup first
        MagicCard.where('name ILIKE ?', "%#{@search_term}%")
      elsif search_empty && @boxset_id.present?
        @collection_cards.where('boxset_id = ?', @boxset_id)
      elsif @search_term.present? && @boxset_id.present?
        @collection_cards.where('name ILIKE ? AND boxset_id = ?', "%#{@search_term}%", @boxset_id)
      else
        @collection_cards.where('name ILIKE ?', "%#{@search_term}%")
      end
    end

    def search_empty
      @search_term.nil? || @search_term.empty?
    end

    def sort_by_card_num(cards)
      # takes in a collection of cards and sorts
      cards.sort_by do |card|
        # try to convert the card_number to an integer, trying to use a Tuple
        [Integer(card.card_number), 0]
      rescue ArgumentError, TypeError
        # if it fails, place it at the end
        [Float::INFINITY, 1]
      end
    end

    def sort_by_price_basic(cards)
      cards.sort_by do |card|
        foil_price = card.foil_price || 0
        normal_price = card.normal_price || 0

        highest_price = [foil_price, normal_price].max

        # default descending order
        -highest_price
      end
    end

    def sort_by_price(cards)
      cards.sort_by do |card|
        # Fetch quantities from the collection
        collection_card = find_card(card)
        normal_quantity = collection_card&.quantity || 0
        foil_quantity = collection_card&.foil_quantity || 0

        normal_price = card.normal_price || 0
        foil_price = card.foil_price || 0

        regular_value = normal_price * normal_quantity
        foil_value = foil_price * foil_quantity
        total_value = regular_value + foil_value

        # descending order
        -total_value
      end
    end

    def find_card(card)
      @collection.collection_magic_cards.find { |c| c.magic_card_id == card.id }
    end
  end
end
