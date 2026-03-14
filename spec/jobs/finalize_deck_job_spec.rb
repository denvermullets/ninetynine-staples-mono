require 'rails_helper'

RSpec.describe FinalizeDeckJob, type: :job do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:source_collection) { create(:collection, user: user) }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0, card_uuid: 'finalize-job-uuid') }

  describe '#perform' do
    context 'when finalization succeeds' do
      let!(:source_card) do
        create(:collection_magic_card,
               collection: source_collection,
               magic_card: magic_card,
               quantity: 4,
               foil_quantity: 0,
               proxy_quantity: 0,
               proxy_foil_quantity: 0,
               staged: false,
               needed: false)
      end

      let!(:staged_card) do
        create(:collection_magic_card,
               collection: deck,
               magic_card: magic_card,
               source_collection_id: source_collection.id,
               staged: true,
               staged_quantity: 2,
               staged_foil_quantity: 0,
               staged_proxy_quantity: 0,
               staged_proxy_foil_quantity: 0,
               quantity: 0,
               foil_quantity: 0)
      end

      it 'calls DeckBuilder::Finalize' do
        expect(DeckBuilder::Finalize).to receive(:call).with(deck: deck).and_call_original
        described_class.new.perform(deck.id, user.id)
      end

      it 'broadcasts a success toast' do
        expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
          "user_#{user.id}_notifications",
          target: 'toasts',
          html: a_string_including('bg-accent-50', 'cards moved')
        )
        allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)
        described_class.new.perform(deck.id, user.id)
      end

      it 'broadcasts a page refresh' do
        allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
        expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to).with(
          "user_#{user.id}_notifications"
        )
        described_class.new.perform(deck.id, user.id)
      end

      it 'includes cards_needed in message when planned cards exist' do
        create(:collection_magic_card,
               collection: deck,
               magic_card: create(:magic_card, card_uuid: 'planned-uuid'),
               source_collection_id: nil,
               staged: true,
               staged_quantity: 3,
               staged_foil_quantity: 0,
               staged_proxy_quantity: 0,
               staged_proxy_foil_quantity: 0,
               quantity: 0,
               foil_quantity: 0)

        expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
          "user_#{user.id}_notifications",
          target: 'toasts',
          html: a_string_including('cards needed')
        )
        allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)
        described_class.new.perform(deck.id, user.id)
      end
    end

    context 'when finalization fails' do
      let!(:source_card) do
        create(:collection_magic_card,
               collection: source_collection,
               magic_card: magic_card,
               quantity: 1,
               foil_quantity: 0,
               staged: false,
               needed: false)
      end

      let!(:staged_card) do
        create(:collection_magic_card,
               collection: deck,
               magic_card: magic_card,
               source_collection_id: source_collection.id,
               staged: true,
               staged_quantity: 5,
               staged_foil_quantity: 0,
               staged_proxy_quantity: 0,
               staged_proxy_foil_quantity: 0,
               quantity: 0,
               foil_quantity: 0)
      end

      it 'broadcasts an error toast' do
        expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
          "user_#{user.id}_notifications",
          target: 'toasts',
          html: a_string_including('bg-accent-100', 'available')
        )
        described_class.new.perform(deck.id, user.id)
      end

      it 'does not broadcast a refresh' do
        allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
        expect(Turbo::StreamsChannel).not_to receive(:broadcast_refresh_to)
        described_class.new.perform(deck.id, user.id)
      end
    end
  end

  describe 'queue' do
    it 'enqueues on collection_updates' do
      expect { described_class.perform_later(deck.id, user.id) }
        .to have_enqueued_job.on_queue('collection_updates')
    end
  end
end
