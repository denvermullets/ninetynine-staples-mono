require 'rails_helper'

RSpec.describe IngestOracleTags, type: :job do
  include ActiveJob::TestHelper

  let(:updated_at) { Time.zone.parse('2026-09-15T21:00:32.671+00:00') }
  let(:download_uri) { 'https://data.scryfall.io/oracle-tags/oracle-tags-20260915210032.jsonl.gz' }
  let(:changed) { [SecureRandom.uuid] }
  let(:result) { { tag_count: 4535, tagging_count: 234_954, changed_oracle_ids: changed } }

  before do
    allow(Scryfall::BulkData).to receive_messages(
      call: { updated_at: updated_at, download_uri: download_uri, compressed_size: 1 },
      each_record: []
    )
    allow(Scryfall::OracleTagsImporter).to receive(:call).and_return(result)
  end

  it 'imports the file, records it, and re-profiles the changed cards' do
    expect { described_class.perform_now }
      .to have_enqueued_job(ProfileCardRolesJob).with(oracle_ids: changed)

    expect(Scryfall::BulkData).to have_received(:each_record).with(download_uri)
    expect(ScryfallBulkImport.find_by!(bulk_type: 'oracle_tags'))
      .to have_attributes(tag_count: 4535, tagging_count: 234_954, remote_updated_at: updated_at)
  end

  it 'skips a file it has already imported' do
    ScryfallBulkImport.create!(bulk_type: 'oracle_tags', remote_updated_at: updated_at)

    expect { described_class.perform_now }.not_to have_enqueued_job(ProfileCardRolesJob)
    expect(Scryfall::OracleTagsImporter).not_to have_received(:call)
  end

  it 're-imports an unchanged file when forced' do
    ScryfallBulkImport.create!(bulk_type: 'oracle_tags', remote_updated_at: updated_at)

    described_class.perform_now(force: true)

    expect(Scryfall::OracleTagsImporter).to have_received(:call)
  end

  # a megabyte of oracle ids in the job arguments buys nothing over an unscoped profile
  it 're-profiles everything when most cards changed' do
    changed.replace(Array.new(described_class::PROFILE_ALL_THRESHOLD + 1) { SecureRandom.uuid })

    expect { described_class.perform_now }.to have_enqueued_job(ProfileCardRolesJob).with(no_args)
  end

  it 'does not re-profile when nothing changed' do
    changed.clear

    expect { described_class.perform_now }.not_to have_enqueued_job(ProfileCardRolesJob)
  end

  it 'does nothing when the index request fails' do
    allow(Scryfall::BulkData).to receive(:call).and_return(error: 'Scryfall bulk-data returned 503')

    described_class.perform_now

    expect(Scryfall::OracleTagsImporter).not_to have_received(:call)
    expect(ScryfallBulkImport.count).to eq(0)
  end
end
