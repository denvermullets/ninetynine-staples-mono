module DeckBuilder
  class StagedQuantities < Service
    QUANTITY_TYPES = %i[regular foil proxy proxy_foil].freeze
    TYPE_LABELS = { regular: 'Regular', foil: 'Foil', proxy: 'Proxy', proxy_foil: 'Foil Proxy' }.freeze
    NOTHING_STAGED = { regular: 0, foil: 0, proxy: 0, proxy_foil: 0 }.freeze

    def initialize(source_collection_id:, magic_card_id:, exclude_card_id: nil)
      @source_collection_id = source_collection_id
      @magic_card_id = magic_card_id
      @exclude_card_id = exclude_card_id
    end

    def call
      {
        regular: staged_scope.sum(:staged_quantity),
        foil: staged_scope.sum(:staged_foil_quantity),
        proxy: staged_scope.sum(:staged_proxy_quantity),
        proxy_foil: staged_scope.sum(:staged_proxy_foil_quantity)
      }
    end

    def self.calculate_available(source:, exclude_card_id: nil)
      staged = call(
        source_collection_id: source.collection_id,
        magic_card_id: source.magic_card_id,
        exclude_card_id: exclude_card_id
      )

      available_from(source, staged)
    end

    # Same numbers as calling calculate_available once per source, in one grouped query instead of four
    # SUMs per row. The per-row path is fine for a single card but turns into thousands of queries once a
    # caller is scoring a whole candidate pool.
    #
    # Keyed by CollectionMagicCard#id rather than by [collection_id, magic_card_id], because nothing stops
    # a collection from holding two rows for the same card.
    def self.calculate_available_batch(sources:, exclude_card_id: nil)
      sources = sources.to_a
      return {} if sources.empty?

      totals = staged_totals(sources: sources, exclude_card_id: exclude_card_id)

      sources.to_h do |source|
        staged = totals[[source.collection_id, source.magic_card_id]] || NOTHING_STAGED
        [source.id, available_from(source, staged)]
      end
    end

    def self.total_staged(source_collection_id:, magic_card_id:, exclude_card_id: nil)
      staged = call(
        source_collection_id: source_collection_id,
        magic_card_id: magic_card_id,
        exclude_card_id: exclude_card_id
      )
      staged.values.sum
    end

    def self.available_from(source, staged)
      {
        regular: [source.quantity - staged[:regular], 0].max,
        foil: [source.foil_quantity - staged[:foil], 0].max,
        proxy: [(source.proxy_quantity || 0) - staged[:proxy], 0].max,
        proxy_foil: [(source.proxy_foil_quantity || 0) - staged[:proxy_foil], 0].max
      }
    end
    private_class_method :available_from

    # Filtering on the two id lists separately over-selects (it is their cross product, not the exact
    # pairs), which is harmless: the result is looked up by exact pair and anything extra is never read.
    def self.staged_totals(sources:, exclude_card_id: nil)
      scope = CollectionMagicCard.staged.where(
        source_collection_id: sources.map(&:collection_id).uniq,
        magic_card_id: sources.map(&:magic_card_id).uniq
      )
      scope = scope.where.not(id: exclude_card_id) if exclude_card_id

      scope.group(:source_collection_id, :magic_card_id)
           .pluck(:source_collection_id, :magic_card_id,
                  Arel.sql('SUM(staged_quantity)'), Arel.sql('SUM(staged_foil_quantity)'),
                  Arel.sql('SUM(staged_proxy_quantity)'), Arel.sql('SUM(staged_proxy_foil_quantity)'))
           .to_h { |row| [[row[0], row[1]], QUANTITY_TYPES.zip(row[2..].map(&:to_i)).to_h] }
    end
    private_class_method :staged_totals

    private

    def staged_scope
      scope = CollectionMagicCard.staged.where(
        source_collection_id: @source_collection_id,
        magic_card_id: @magic_card_id
      )
      scope = scope.where.not(id: @exclude_card_id) if @exclude_card_id
      scope
    end
  end
end
