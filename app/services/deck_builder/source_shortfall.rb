module DeckBuilder
  # A staged row pulled from a collection is finalized by taking its copies out of that exact printing in
  # the source, type by type: a foil copy can't be covered by a regular one. Everything that puts copies on
  # a staged row, and everything that warns about one, checks it the same way Finalize will.
  class SourceShortfall < Service
    TYPES = %i[regular foil proxy proxy_foil].freeze
    LABELS = { regular: 'regular', foil: 'foil', proxy: 'proxy', proxy_foil: 'foil proxy' }.freeze
    STAGED_COLUMNS = {
      regular: :staged_quantity, foil: :staged_foil_quantity,
      proxy: :staged_proxy_quantity, proxy_foil: :staged_proxy_foil_quantity
    }.freeze

    # The first type the source can't cover, as { type:, needed:, available: }, or nil when it covers all
    def self.first(needed:, available:)
      type = TYPES.find { |t| needed[t].to_i > available[t].to_i }
      type && { type: type, needed: needed[type].to_i, available: available[type].to_i }
    end

    def self.staged_on(card) = STAGED_COLUMNS.transform_values { |column| card.public_send(column) }

    def self.held_by(source)
      {
        regular: source.quantity.to_i, foil: source.foil_quantity.to_i,
        proxy: source.proxy_quantity.to_i, proxy_foil: source.proxy_foil_quantity.to_i
      }
    end

    def initialize(deck:)
      @deck = deck
    end

    # { staged row id => what's wrong } for every staged row its source can no longer finalize. Measured
    # against what the source holds right now, as Finalize does, so a row listed here is one Finalize refuses
    def call
      cards = @deck.collection_magic_cards.staged.from_collection.includes(:magic_card, :source_collection).to_a
      return {} if cards.empty?

      sources = load_sources(cards)
      cards.each_with_object({}) do |card, issues|
        issue = issue_for(card, sources[[card.source_collection_id, card.magic_card_id]])
        issues[card.id] = issue if issue
      end
    end

    private

    # Filtering on the two id lists separately over-selects (their cross product, not the exact pairs);
    # anything extra is never looked up
    def load_sources(cards)
      CollectionMagicCard.where(
        collection_id: cards.map(&:source_collection_id).uniq,
        magic_card_id: cards.map(&:magic_card_id).uniq,
        staged: false, needed: false
      ).index_by { |source| [source.collection_id, source.magic_card_id] }
    end

    def issue_for(card, source)
      source_name = card.source_collection.name
      return "#{source_name} no longer has this printing" unless source

      short = self.class.first(needed: self.class.staged_on(card), available: self.class.held_by(source))
      return unless short

      held = self.class.held_by(source).select { |_type, count| count.positive? }
                 .map { |type, count| "#{count} #{LABELS[type]}" }
      "#{source_name} has #{short[:available]} #{LABELS[short[:type]]}" \
        "#{" (#{held.join(', ')})" if held.any?}, #{short[:needed]} staged"
    end
  end
end
