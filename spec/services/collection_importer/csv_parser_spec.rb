require 'rails_helper'

RSpec.describe CollectionImporter::CsvParser, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user, collection_type: 'collection') }

  describe '#call' do
    context 'with valid CSV' do
      let(:csv_data) do
        <<~CSV
          Quantity,Name,Edition Code,Scryfall ID,Finish
          2,Lightning Bolt,2XM,#{SecureRandom.uuid},Normal
          1,Ad Nauseam,2XM,#{SecureRandom.uuid},Foil
        CSV
      end

      it 'returns success with rows queued count' do
        result = described_class.call(csv_data: csv_data, collection: collection, user: user)
        expect(result[:action]).to eq(:success)
        expect(result[:rows_queued]).to eq(2)
      end

      it 'enqueues ImportCollectionRowJob for each row' do
        expect {
          described_class.call(csv_data: csv_data, collection: collection, user: user)
        }.to have_enqueued_job(ImportCollectionRowJob).exactly(2).times
      end
    end

    context 'with alternate-cased headers' do
      let(:csv_data) do
        <<~CSV
          quantity,name,edition code,scryfall id,finish
          2,Lightning Bolt,2XM,#{SecureRandom.uuid},Normal
        CSV
      end

      it 'matches headers case-insensitively' do
        result = described_class.call(csv_data: csv_data, collection: collection, user: user)
        expect(result[:action]).to eq(:success)
        expect(result[:rows_queued]).to eq(1)
      end
    end

    context 'with "scryfall ID" header' do
      let(:csv_data) do
        <<~CSV
          Quantity,Name,Edition Code,scryfall ID,Finish
          1,Lightning Bolt,2XM,#{SecureRandom.uuid},Normal
        CSV
      end

      it 'matches the header' do
        result = described_class.call(csv_data: csv_data, collection: collection, user: user)
        expect(result[:action]).to eq(:success)
        expect(result[:rows_queued]).to eq(1)
      end
    end

    context 'with Archidekt modifier column instead of finish' do
      let(:foil_uuid) { SecureRandom.uuid }
      let(:normal_uuid) { SecureRandom.uuid }
      let(:csv_data) do
        <<~CSV
          Quantity,Name,Edition Code,Scryfall ID,Modifier
          1,Lightning Bolt,2XM,#{normal_uuid},Normal
          1,Ad Nauseam,2XM,#{foil_uuid},Foil
        CSV
      end

      it 'maps modifier to finish for foil detection' do
        expect(ImportCollectionRowJob).to receive(:perform_later)
          .with(collection.id, hash_including(finish: 'Normal'), skip_existing: false)
        expect(ImportCollectionRowJob).to receive(:perform_later)
          .with(collection.id, hash_including(finish: 'Foil'), skip_existing: false)

        described_class.call(csv_data: csv_data, collection: collection, user: user)
      end
    end

    context 'with missing required headers' do
      let(:csv_data) do
        <<~CSV
          Name,Edition Code
          Lightning Bolt,2XM
        CSV
      end

      it 'raises ArgumentError' do
        expect {
          described_class.call(csv_data: csv_data, collection: collection, user: user)
        }.to raise_error(ArgumentError, /scryfall id/)
      end
    end

    context 'with blank scryfall_id rows' do
      let(:csv_data) do
        <<~CSV
          Quantity,Name,Edition Code,Scryfall ID,Finish
          2,Lightning Bolt,2XM,,Normal
          1,Ad Nauseam,2XM,#{SecureRandom.uuid},Foil
        CSV
      end

      it 'skips rows with blank scryfall_id' do
        result = described_class.call(csv_data: csv_data, collection: collection, user: user)
        expect(result[:rows_queued]).to eq(1)
      end
    end

    context 'with zero quantity rows' do
      let(:csv_data) do
        <<~CSV
          Quantity,Name,Edition Code,Scryfall ID,Finish
          0,Lightning Bolt,2XM,#{SecureRandom.uuid},Normal
        CSV
      end

      it 'skips rows with zero quantity' do
        result = described_class.call(csv_data: csv_data, collection: collection, user: user)
        expect(result[:rows_queued]).to eq(0)
      end
    end
  end
end
