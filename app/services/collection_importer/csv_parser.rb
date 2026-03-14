require 'csv'

module CollectionImporter
  class CsvParser < Service
    REQUIRED_HEADERS = ['Scryfall ID', 'Quantity'].freeze

    def initialize(csv_data:, collection:, user:)
      @csv_data = csv_data
      @collection = collection
      @user = user
    end

    def call
      rows = CSV.parse(@csv_data, headers: true)

      validate_headers!(rows.headers)

      rows_queued = 0
      rows.each do |row|
        row_data = {
          scryfall_id: row['Scryfall ID'],
          quantity: row['Quantity'].to_i,
          finish: row['Finish'],
          name: row['Name'],
          edition_code: row['Edition Code']
        }

        next if row_data[:scryfall_id].blank? || row_data[:quantity] < 1

        ImportCollectionRowJob.perform_later(@collection.id, row_data)
        rows_queued += 1
      end

      { action: :success, rows_queued: rows_queued }
    end

    private

    def validate_headers!(headers)
      missing = REQUIRED_HEADERS - (headers || [])
      return if missing.empty?

      raise ArgumentError, "CSV missing required headers: #{missing.join(', ')}"
    end
  end
end
