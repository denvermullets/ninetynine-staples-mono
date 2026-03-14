require 'rails_helper'

RSpec.describe ImportCollectionRowJob, type: :job do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user, collection_type: 'collection') }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0, card_uuid: SecureRandom.uuid) }
  let(:scryfall_id) { SecureRandom.uuid }

  before do
    MagicCardIdentifier.create!(magic_card: magic_card, scryfall_id: scryfall_id)
  end

  describe '#perform' do
    let(:row_data) do
      { 'scryfall_id' => scryfall_id, 'quantity' => 2, 'finish' => 'Normal', 'name' => 'Lightning Bolt',
        'edition_code' => '2XM' }
    end

    it 'calls CollectionImporter::Archidekt' do
      expect(CollectionImporter::Archidekt).to receive(:call).with(
        row_data: row_data,
        collection: collection,
        skip_existing: false
      ).and_call_original

      described_class.new.perform(collection.id, row_data)
    end

    it 'passes skip_existing option' do
      expect(CollectionImporter::Archidekt).to receive(:call).with(
        row_data: row_data,
        collection: collection,
        skip_existing: true
      ).and_call_original

      described_class.new.perform(collection.id, row_data, skip_existing: true)
    end

    it 'imports the card into the collection' do
      expect {
        described_class.new.perform(collection.id, row_data)
      }.to change { collection.collection_magic_cards.count }.by(1)
    end
  end

  describe 'queue' do
    it 'enqueues on collection_updates' do
      expect {
        described_class.perform_later(collection.id, {})
      }.to have_enqueued_job.on_queue('collection_updates')
    end
  end
end
