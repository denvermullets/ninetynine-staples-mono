module CardScanner
  class Search < Service
    MAX_RESULTS = 1
    GARBAGE_WORDS = %w[the and for with from into onto upon that this].freeze

    def initialize(set_code: nil, card_number: nil, query: nil, user: nil)
      @set_code = set_code&.strip&.upcase
      @card_number = card_number&.strip&.gsub(%r{/.*}, '')
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
      if @set_code.present? && @card_number.present?
        exact_match = find_by_set_and_number
        return [exact_match] if exact_match
      end
      return [] if @query.blank?

      find_by_name
    end

    def find_by_set_and_number
      MagicCard.joins(:boxset)
               .where(boxsets: { code: @set_code })
               .where(card_number: @card_number)
               .where(card_side: [nil, 'a'])
               .first
    end

    def find_by_name
      cleaned_query = clean_ocr_text(@query)
      return [] if cleaned_query.blank?

      words = extract_significant_words(cleaned_query)
      return [] if words.empty?

      search_with_words(words)
    end

    def extract_significant_words(text)
      text.split(/[\s,]+/)
          .map { |w| w.gsub(/[^a-zA-Z'-]/, '') }
          .select { |w| w.length >= 3 }
          .reject { |w| GARBAGE_WORDS.include?(w.downcase) }
          .first(5)
    end

    def search_with_words(words)
      conditions = words.map { 'magic_cards.name ILIKE ?' }
      values = words.map { |w| "%#{w}%" }

      cards = MagicCard.joins(:boxset)
                       .where(conditions.join(' OR '), *values)
                       .where(card_side: [nil, 'a'])
                       .order('boxsets.release_date DESC')
                       .limit(100)

      scored = cards.map { |card| [card, count_word_matches(card, words)] }
      sorted = scored.sort_by { |_, count| -count }.map(&:first)
      dedupe_by_name(sorted)
    end

    def count_word_matches(card, words)
      words.count { |w| card.name.downcase.include?(w.downcase) }
    end

    def clean_ocr_text(text)
      return nil if text.blank?

      text.gsub(/[^a-zA-Z0-9\s,'-]/, '').gsub(/\s+/, ' ').strip
    end

    def dedupe_by_name(cards)
      seen_names = Set.new
      cards.each_with_object([]) do |card, unique|
        next if seen_names.include?(card.name)

        seen_names.add(card.name)
        unique << card
        break unique if unique.size >= MAX_RESULTS
      end
    end

    def enrich_with_ownership(cards)
      return cards unless @user

      owned = fetch_owned_quantities(cards.map(&:id))
      cards.map { |card| { card: card, owned: owned[card.id] || default_owned } }
    end

    def default_owned
      { quantity: 0, foil_quantity: 0, proxy_quantity: 0, proxy_foil_quantity: 0 }
    end

    def fetch_owned_quantities(card_ids)
      records = CollectionMagicCard.joins(:collection)
                                   .where(magic_card_id: card_ids)
                                   .where(collections: { user_id: @user.id })
                                   .where.not(
                                     'collections.collection_type = ? OR collections.collection_type LIKE ?',
                                     'deck', '%_deck'
                                   )
                                   .group(:magic_card_id)
                                   .select(
                                     :magic_card_id,
                                     'SUM(quantity) as quantity',
                                     'SUM(foil_quantity) as foil_quantity',
                                     'SUM(proxy_quantity) as proxy_quantity',
                                     'SUM(proxy_foil_quantity) as proxy_foil_quantity'
                                   )

      records.index_by(&:magic_card_id).transform_values do |r|
        {
          quantity: r.quantity.to_i,
          foil_quantity: r.foil_quantity.to_i,
          proxy_quantity: r.proxy_quantity.to_i,
          proxy_foil_quantity: r.proxy_foil_quantity.to_i
        }
      end
    end
  end
end
