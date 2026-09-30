require 'csv'

# One row per printing, summed across the given collections, in the shape CollectionImporter::CsvParser
# reads back - export, delete, re-import and every normal/foil/proxy count comes back where it was.
# Staged and needed deck-builder rows are plans, not cards on hand, so they stay out.
module CollectionExporter
  class Csv < Service
    HEADERS = [
      'Scryfall ID', 'Name', 'Edition Code', 'Collector Number',
      'Quantity', 'Foil Quantity', 'Proxy Quantity', 'Proxy Foil Quantity'
    ].freeze
    COLLECTIONS_HEADER = 'Collections'.freeze

    # list_collections adds a column naming where each card lives - for the export-everything file
    def initialize(collections:, list_collections: false)
      @collections = collections
      @list_collections = list_collections
    end

    def call
      CSV.generate do |csv|
        csv << (@list_collections ? HEADERS + [COLLECTIONS_HEADER] : HEADERS)
        rows.each { |row| csv << row }
      end
    end

    private

    def rows
      CollectionMagicCard.finalized.owned
                         .where(collection: @collections)
                         .joins(:collection, magic_card: %i[magic_card_identifier boxset])
                         .group('magic_card_identifiers.scryfall_id', 'magic_cards.name',
                                'boxsets.code', 'magic_cards.card_number')
                         .having(any_copies_sql)
                         .order('magic_cards.name', 'boxsets.code', 'magic_cards.card_number')
                         .pluck(*columns)
    end

    def columns
      sums = %w[quantity foil_quantity proxy_quantity proxy_foil_quantity].map do |column|
        Arel.sql("SUM(collection_magic_cards.#{column})")
      end
      base = [
        'magic_card_identifiers.scryfall_id', 'magic_cards.name', 'UPPER(boxsets.code)', 'magic_cards.card_number'
      ].map { |sql| Arel.sql(sql) } + sums
      return base unless @list_collections

      base + [Arel.sql("STRING_AGG(DISTINCT collections.name, '; ' ORDER BY collections.name)")]
    end

    def any_copies_sql
      'SUM(collection_magic_cards.quantity + collection_magic_cards.foil_quantity + ' \
        'collection_magic_cards.proxy_quantity + collection_magic_cards.proxy_foil_quantity) > 0'
    end
  end
end
