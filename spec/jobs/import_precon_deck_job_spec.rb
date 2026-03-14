require 'rails_helper'

RSpec.describe ImportPreconDeckJob, type: :job do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user, collection_type: 'deck') }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0) }
  let(:precon_deck) { PreconDeck.create!(code: 'TST', file_name: 'test_import_job', name: 'Test Precon') }

  before do
    PreconDeckCard.create!(
      precon_deck: precon_deck, magic_card: magic_card,
      board_type: 'mainBoard', quantity: 4, is_foil: false
    )
  end

  describe '#perform' do
    it 'calls PreconDeckImporter' do
      expect(PreconDeckImporter).to receive(:call).with(
        precon_deck: precon_deck,
        collection: collection
      ).and_call_original
      described_class.new.perform(precon_deck.id, collection.id, user.id)
    end

    it 'imports cards into the collection' do
      expect { described_class.new.perform(precon_deck.id, collection.id, user.id) }
        .to change { collection.collection_magic_cards.count }.by(1)
    end

    it 'broadcasts a success toast' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
        "user_#{user.id}_notifications",
        target: 'toasts',
        html: a_string_including('bg-accent-50', 'imported successfully')
      )
      described_class.new.perform(precon_deck.id, collection.id, user.id)
    end

    it 'includes card count in toast message' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
        "user_#{user.id}_notifications",
        target: 'toasts',
        html: a_string_including('1 cards')
      )
      described_class.new.perform(precon_deck.id, collection.id, user.id)
    end
  end

  describe 'queue' do
    it 'enqueues on collection_updates' do
      expect { described_class.perform_later(precon_deck.id, collection.id, user.id) }
        .to have_enqueued_job.on_queue('collection_updates')
    end
  end
end
