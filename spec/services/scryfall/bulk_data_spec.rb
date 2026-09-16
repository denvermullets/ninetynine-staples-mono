require 'rails_helper'

RSpec.describe Scryfall::BulkData, type: :service do
  let(:index_url) { 'https://api.scryfall.com/bulk-data/oracle_tags' }
  let(:download_uri) { 'https://data.scryfall.io/oracle-tags/oracle-tags-20260915210032.jsonl.gz' }

  describe '.call' do
    let(:body) do
      {
        'object' => 'bulk_data', 'type' => 'oracle_tags', 'updated_at' => '2026-09-15T21:00:32.671+00:00',
        'jsonl_download_uri' => download_uri, 'compressed_size' => 5_972_114
      }
    end

    def stub_index(code: 200, parsed: body)
      response = instance_double(HTTParty::Response, code: code, parsed_response: parsed)
      allow(HTTParty).to receive(:get).and_return(response)
    end

    # Scryfall's live tag entries carry jsonl_download_uri; the documented download_uri is absent
    it 'reads the download uri and updated_at from the index entry' do
      stub_index

      result = described_class.call(type: 'oracle_tags')

      expect(result[:download_uri]).to eq(download_uri)
      expect(result[:updated_at]).to eq(Time.zone.parse('2026-09-15T21:00:32.671+00:00'))
      expect(result[:compressed_size]).to eq(5_972_114)
    end

    # required by Scryfall's API terms
    it 'sends a User-Agent and an Accept header' do
      stub_index

      described_class.call(type: 'oracle_tags')

      expect(HTTParty).to have_received(:get).with(
        index_url,
        hash_including(headers: hash_including('User-Agent' => start_with('NinetyNineStaples/'),
                                               'Accept' => be_present))
      )
    end

    it 'returns an error for a non-200 response' do
      stub_index(code: 503)

      expect(described_class.call(type: 'oracle_tags')).to eq(error: 'Scryfall bulk-data returned 503')
    end

    it 'returns an error when the entry has no download uri' do
      stub_index(parsed: body.except('jsonl_download_uri'))

      expect(described_class.call(type: 'oracle_tags')[:error]).to include('no download uri')
    end

    it 'returns an error on timeout' do
      allow(HTTParty).to receive(:get).and_raise(Net::ReadTimeout)

      expect(described_class.call(type: 'oracle_tags')).to eq(error: 'Scryfall bulk-data request timed out')
    end
  end

  describe '.each_record' do
    let(:records) do
      [{ 'object' => 'tag', 'slug' => 'ramp' }, { 'object' => 'tag', 'slug' => 'sweeper' }]
    end
    let(:jsonl) { "#{records.map(&:to_json).join("\n")}\n\n" }

    def stub_download(payload, code: 200)
      allow(HTTParty).to receive(:get) do |_url, **_options, &block|
        fragment = payload.dup
        fragment.define_singleton_method(:code) { code }
        block.call(fragment)
        instance_double(HTTParty::Response, code: code)
      end
    end

    it 'yields one parsed record per line of a gzipped file' do
      stub_download(Zlib.gzip(jsonl))

      expect(described_class.each_record(download_uri).to_a).to eq(records)
    end

    # an HTTP client that negotiated gzip transfer encoding hands back the file already inflated
    it 'also reads a file that arrives already inflated' do
      stub_download(jsonl)

      expect(described_class.each_record(download_uri).to_a).to eq(records)
    end

    it 'raises when the download fails' do
      stub_download('Not Found', code: 404)

      expect { described_class.each_record(download_uri).to_a }.to raise_error(described_class::DownloadError)
    end
  end
end
