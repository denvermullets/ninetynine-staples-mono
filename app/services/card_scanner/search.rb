# frozen_string_literal: true

module CardScanner
  class Search < Service
    GARBAGE_WORDS = %w[the and for with from into onto upon that this].freeze
    DEFAULT_OWNED = { quantity: 0, foil_quantity: 0, proxy_quantity: 0, proxy_foil_quantity: 0 }.freeze

    def initialize(set_code: nil, card_number: nil, query: nil, user: nil)
      @set_code = set_code&.strip&.upcase
      @card_number = card_number&.strip&.gsub(%r{/.*}, '')
      @query = query&.strip
      @user = user
    end

    def call
      return [] if no_search_criteria?

      best_match = find_best_match
      return [] unless best_match

      cards = all_printings_for(best_match)
      enrich_with_ownership(cards)
    end

    private

    def no_search_criteria?
      @set_code.blank? && @card_number.blank? && @query.blank?
    end

    def find_best_match
      find_by_set_and_number || find_best_by_name
    end

    def find_by_set_and_number
      return nil unless @set_code.present? && @card_number.present?

      base_card_scope.where(boxsets: { code: @set_code }, card_number: @card_number).first
    end

    def find_best_by_name
      return nil if @query.blank?

      words = extract_significant_words(clean_ocr_text(@query))
      return nil if words.empty?

      find_best_match_for_words(words)
    end

    def base_card_scope
      MagicCard.joins(:boxset).where(card_side: [nil, 'a'], is_token: false)
    end

    def extract_significant_words(text)
      return [] if text.blank?

      text.split(/[\s,]+/)
          .map { |w| w.gsub(/[^a-zA-Z'-]/, '') }
          .select { |w| w.length >= 3 }
          .reject { |w| GARBAGE_WORDS.include?(w.downcase) }
          .first(5)
    end

    def find_best_match_for_words(words)
      conditions = words.map { 'magic_cards.name ILIKE ?' }
      values = words.map { |w| "%#{w}%" }

      cards = base_card_scope.where(conditions.join(' OR '), *values)
                             .order('boxsets.release_date DESC')
                             .limit(100)

      score_and_select_best(cards, words)
    end

    def score_and_select_best(cards, words)
      cards.max_by { |card| words.count { |w| card.name.downcase.include?(w.downcase) } }
    end

    def clean_ocr_text(text)
      return nil if text.blank?

      text.gsub(/[^a-zA-Z0-9\s,'-]/, '').gsub(/\s+/, ' ').strip
    end

    def all_printings_for(card)
      return [card] if card.scryfall_oracle_id.blank?

      base_card_scope.where(scryfall_oracle_id: card.scryfall_oracle_id)
                     .order('boxsets.release_date DESC')
    end

    def enrich_with_ownership(cards)
      owned = OwnershipLoader.call(card_ids: cards.map(&:id), user: @user)
      cards.map { |card| { card: card, owned: owned[card.id] || DEFAULT_OWNED } }
    end
  end
end
