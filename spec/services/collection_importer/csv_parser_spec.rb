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
        }.to raise_error(ArgumentError, /Scryfall ID/)
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
