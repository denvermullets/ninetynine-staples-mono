require 'csv'

module CollectionImporter
  class CsvParser < Service
    REQUIRED_HEADERS = ['scryfall id', 'quantity'].freeze
    # our own export - one row per card with a column per finish, where Archidekt's Quantity is per Finish
    COUNT_HEADERS = {
      foil_quantity: 'foil quantity', proxy_quantity: 'proxy quantity', proxy_foil_quantity: 'proxy foil quantity'
    }.freeze
    PROXY_KEYS = %i[proxy_quantity proxy_foil_quantity].freeze

    def initialize(csv_data:, collection:, user:, skip_existing: false, skip_proxies: false)
      @csv_data = csv_data
      @collection = collection
      @user = user
      @skip_existing = skip_existing
      @skip_proxies = skip_proxies
    end

    def call
      rows = CSV.parse(@csv_data, headers: true, liberal_parsing: true, header_converters: ->(h) { h&.strip })

      @header_map = build_header_map(rows.headers)
      validate_headers!(@header_map)

      rows_queued = 0
      rows.each do |row|
        row_data = extract_row_data(row)

        next if row_data[:scryfall_id].blank? || !any_copies?(row_data)

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
        finish: row[@header_map['finish']] || row[@header_map['modifier']],
        name: row[@header_map['name']],
        edition_code: row[@header_map['edition code']]
      }.merge(count_data(row))
    end

    # only the count columns the file has, so an Archidekt row still goes through its Finish
    def count_data(row)
      COUNT_HEADERS.each_with_object({}) do |(key, header), data|
        next unless @header_map.key?(header)

        data[key] = @skip_proxies && PROXY_KEYS.include?(key) ? 0 : row[@header_map[header]].to_i
      end
    end

    def any_copies?(row_data)
      [:quantity, *COUNT_HEADERS.keys].sum { |key| [row_data[key].to_i, 0].max }.positive?
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
