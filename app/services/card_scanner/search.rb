module CardScanner
  class Search < Service
    MAX_RESULTS = 10

    def initialize(set_code: nil, card_number: nil, query: nil, user: nil)
      @set_code = set_code&.strip&.upcase
      @card_number = card_number&.strip&.gsub(%r{/.*}, '') # Remove "/287" from "123/287"
      @query = query&.strip
      @user = user
    end

    def call
      return [] if no_search_criteria?

      cards = search_cards
      return [] if cards.empty?

      enrich_with_ownership(cards)
    end

    private

    def no_search_criteria?
      @set_code.blank? && @card_number.blank? && @query.blank?
    end

    def search_cards
      # Primary: Try exact match by set code + collector number
      if @set_code.present? && @card_number.present?
        exact_match = find_by_set_and_number
        return [exact_match] if exact_match
      end

      # Fallback: Search by name
      return [] if @query.blank?

      find_by_name
    end

    def find_by_set_and_number
      MagicCard
        .joins(:boxset)
        .where(boxsets: { code: @set_code })
        .where(card_number: @card_number)
        .where(card_side: [nil, 'a']) # Prefer front face for DFCs
        .first
    end

    def find_by_name
      cleaned_query = clean_ocr_text(@query)
      return [] if cleaned_query.blank?

      # Search for cards matching the name
      cards = MagicCard
              .joins(:boxset)
              .where('magic_cards.name ILIKE ?', "%#{cleaned_query}%")
              .where(card_side: [nil, 'a']) # Prefer front face
              .order('boxsets.release_date DESC')
              .limit(100)

      # Group by card name and return newest printing of each
      dedupe_by_name(cards)
    end

    def clean_ocr_text(text)
      return nil if text.blank?

      text
        .gsub(/[^a-zA-Z0-9\s,'-]/, '') # Remove special characters except common ones
        .gsub(/\s+/, ' ')              # Normalize whitespace
        .strip
    end

    def dedupe_by_name(cards)
      seen_names = Set.new
      unique_cards = []

      cards.each do |card|
        next if seen_names.include?(card.name)

        seen_names.add(card.name)
        unique_cards << card
        break if unique_cards.size >= MAX_RESULTS
      end

      unique_cards
    end

    def enrich_with_ownership(cards)
      return cards unless @user

      card_ids = cards.map(&:id)

      # Get owned quantities for these cards
      owned = CollectionMagicCard
              .joins(:collection)
              .where(magic_card_id: card_ids)
              .where(collections: { user_id: @user.id })
              .where.not('collections.collection_type = ? OR collections.collection_type LIKE ?', 'deck', '%_deck')
              .group(:magic_card_id)
              .sum('collection_magic_cards.quantity + collection_magic_cards.foil_quantity')

      cards.map do |card|
        {
          card: card,
          owned_quantity: owned[card.id] || 0
        }
      end
    end
  end
end
