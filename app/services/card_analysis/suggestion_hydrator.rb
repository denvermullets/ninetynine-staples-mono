module CardAnalysis
  # Attaches a printing to the suggestions that actually made a bucket.
  #
  # Kept out of CommanderSynergy because it is the one presentation-shaped step in an otherwise
  # numeric pipeline, and because the timing matters: entries stay as plain scored data until the
  # buckets are decided, so this loads a few dozen rows rather than the whole candidate pool.
  # Instantiating ~10k MagicCards with their boxsets to display 96 of them was most of the request.
  class SuggestionHydrator < Service
    def initialize(buckets:)
      @buckets = buckets
    end

    # -> the same buckets with magic_card merged into each card. Anything that fails to resolve is
    # dropped rather than rendered half-built, and a bucket left with nothing goes with it.
    def call
      cards = load_cards(@buckets.flat_map { |bucket| bucket[:cards] }.pluck(:oracle_id))

      @buckets.filter_map do |bucket|
        hydrated = bucket[:cards].filter_map do |entry|
          card = cards[entry[:oracle_id]]
          entry.merge(magic_card: card) if card
        end

        bucket.merge(cards: hydrated) if hydrated.any?
      end
    end

    private

    def load_cards(oracle_ids)
      return {} if oracle_ids.empty?

      MagicCard.where(scryfall_oracle_id: oracle_ids, card_side: [nil, 'a'])
               .includes(:boxset)
               .order('boxsets.release_date DESC')
               .index_by(&:scryfall_oracle_id)
    end
  end
end
