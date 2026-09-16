require 'zlib'

# Scryfall's documented bulk-data files. Two requests per import - the index entry, then the file - and no
# per-card API calls.
#
# Scryfall's API terms require an accurate User-Agent and an Accept header on every request.
module Scryfall
  class BulkData < Service
    API_URL = 'https://api.scryfall.com/bulk-data'.freeze
    TIMEOUT = 30
    DOWNLOAD_TIMEOUT = 300
    ACCEPT = 'application/json;q=0.9,*/*;q=0.8'.freeze
    GZIP_MAGIC = "\x1F\x8B".b.freeze

    class DownloadError < StandardError; end

    def self.headers
      domain = ENV.fetch('APP_DOMAIN', nil)
      agent = domain.present? ? "NinetyNineStaples/1.0 (+#{domain})" : 'NinetyNineStaples/1.0'

      { 'User-Agent' => agent, 'Accept' => ACCEPT }
    end

    # Downloads the file whole to a tempfile, then yields one parsed JSONL record at a time, so the
    # file is never held in memory as a single parsed document.
    def self.each_record(download_uri, &)
      return enum_for(:each_record, download_uri) unless block_given?

      Tempfile.create(['scryfall-bulk', '.jsonl'], binmode: true) do |file|
        download(download_uri, file)
        each_line(file.path) do |line|
          yield JSON.parse(line.force_encoding(Encoding::UTF_8)) if line.strip.present?
        end
      end
    end

    def self.download(download_uri, file)
      response = HTTParty.get(download_uri, headers: headers, timeout: DOWNLOAD_TIMEOUT,
                                            stream_body: true) do |fragment|
        file.write(fragment) if fragment.code == 200
      end
      raise DownloadError, "#{download_uri} returned #{response.code}" unless response.code == 200

      file.flush
    end

    # The file is published gzipped, but an HTTP client that negotiates gzip transfer encoding will
    # already have inflated it, so sniff the bytes rather than trusting the extension.
    def self.each_line(path, &)
      if File.binread(path, 2) == GZIP_MAGIC
        Zlib::GzipReader.open(path) { |gz| gz.each_line(&) }
      else
        File.foreach(path, &)
      end
    end

    def initialize(type:)
      @type = type
    end

    # -> { updated_at:, download_uri:, compressed_size: } or { error: }
    def call
      response = HTTParty.get("#{API_URL}/#{@type}", headers: self.class.headers, timeout: TIMEOUT)
      return api_error(response) unless response.code == 200

      parse(response.parsed_response)
    rescue Net::OpenTimeout, Net::ReadTimeout
      log 'TIMEOUT'
      { error: 'Scryfall bulk-data request timed out' }
    rescue StandardError => e
      log "ERROR: #{e.class}: #{e.message}"
      { error: "Scryfall bulk-data error: #{e.message}" }
    end

    private

    def log(message) = Rails.logger.info("[Scryfall::BulkData] #{message}")

    def api_error(response)
      log "API error #{response.code} for #{@type}"
      { error: "Scryfall bulk-data returned #{response.code}" }
    end

    # Tag files expose jsonl_download_uri only; the card files use download_uri. Accept either.
    def parse(body)
      uri = body['jsonl_download_uri'].presence || body['download_uri'].presence
      return { error: "Scryfall bulk-data entry for #{@type} has no download uri" } if uri.nil?

      {
        updated_at: Time.zone.parse(body['updated_at'].to_s),
        download_uri: uri,
        compressed_size: body['compressed_size'] || body['size']
      }
    end
  end
end
