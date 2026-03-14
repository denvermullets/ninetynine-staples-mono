require 'csv'

module CollectionImporter
  class CsvParser < Service
    REQUIRED_HEADERS = ['scryfall id', 'quantity'].freeze

    def initialize(csv_data:, collection:, user:, skip_existing: false)
      @csv_data = csv_data
      @collection = collection
      @user = user
      @skip_existing = skip_existing
    end

    def call
      rows = CSV.parse(@csv_data, headers: true, header_converters: ->(h) { h&.strip })

      @header_map = build_header_map(rows.headers)
      validate_headers!(@header_map)

      rows_queued = 0
      rows.each do |row|
        row_data = extract_row_data(row)

        next if row_data[:scryfall_id].blank? || row_data[:quantity] < 1

        ImportCollectionRowJob.perform_later(@collection.id, row_data, skip_existing: @skip_existing)
        rows_queued += 1
      end

      { action: :success, rows_queued: rows_queued }
    end

    private

    def extract_row_data(row)
      {
        scryfall_id: row[@header_map['scryfall id']],
        quantity: row[@header_map['quantity']].to_i,
        finish: row[@header_map['finish']],
        name: row[@header_map['name']],
        edition_code: row[@header_map['edition code']]
      }
    end

    def build_header_map(headers)
      (headers || []).to_h do |header|
        [header.downcase, header]
      end
    end

    def validate_headers!(header_map)
      missing = REQUIRED_HEADERS.reject { |h| header_map.key?(h) }
      return if missing.empty?

      raise ArgumentError, "CSV missing required headers: #{missing.join(', ')}"
    end
  end
end
