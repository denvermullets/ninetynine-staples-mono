require 'rails_helper'

RSpec.describe DestroyDeckJob, type: :job do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'commander_deck') }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0, card_uuid: 'destroy-deck-uuid') }

  describe '#perform' do
    context 'when deck exists with cards' do
      let!(:deck_card) do
        create(:collection_magic_card,
               collection: deck,
               magic_card: magic_card,
               quantity: 1,
               foil_quantity: 0,
               staged: false,
               needed: false)
      end

      it 'deletes all collection_magic_cards for the deck' do
        expect { described_class.new.perform(deck.id, user.id) }
          .to change { CollectionMagicCard.where(collection_id: deck.id).count }.from(1).to(0)
      end

      it 'destroys the deck' do
        described_class.new.perform(deck.id, user.id)
        expect(Collection.find_by(id: deck.id)).to be_nil
      end

      it 'broadcasts a remove stream to remove the deck card from the DOM' do
        expect(Turbo::StreamsChannel).to receive(:broadcast_remove_to).with(
          "user_#{user.id}_notifications",
          target: "collection_card_#{deck.id}"
        )
        allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
        described_class.new.perform(deck.id, user.id)
      end

      it 'broadcasts a success toast' do
        allow(Turbo::StreamsChannel).to receive(:broadcast_remove_to)
        expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
          "user_#{user.id}_notifications",
          target: 'toasts',
          html: a_string_including('bg-accent-50', deck.name)
        )
        described_class.new.perform(deck.id, user.id)
      end
    end

    context 'when deck has sourced cards from another collection' do
      let(:source_collection) { create(:collection, user: user) }

      let!(:source_card) do
        create(:collection_magic_card,
               collection: source_collection,
               magic_card: magic_card,
               quantity: 4,
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
               staged_quantity: 2,
               staged_foil_quantity: 0,
               staged_proxy_quantity: 0,
               staged_proxy_foil_quantity: 0,
               quantity: 0,
               foil_quantity: 0)
      end

      it 'does not delete cards in the source collection' do
        described_class.new.perform(deck.id, user.id)
        expect(source_card.reload).to be_present
      end
    end

    context 'when other collections have cards sourced from this deck' do
      let(:other_deck) { create(:collection, user: user, collection_type: 'commander_deck') }

      let!(:deck_card) do
        create(:collection_magic_card,
               collection: deck,
               magic_card: magic_card,
               quantity: 2,
               foil_quantity: 0,
               staged: false,
               needed: false)
      end

      let!(:sourced_card) do
        create(:collection_magic_card,
               collection: other_deck,
               magic_card: magic_card,
               source_collection_id: deck.id,
               staged: true,
               staged_quantity: 1,
               staged_foil_quantity: 0,
               staged_proxy_quantity: 0,
               staged_proxy_foil_quantity: 0,
               quantity: 0,
               foil_quantity: 0)
      end

      it 'nullifies source_collection_id on cards sourced from this deck' do
        described_class.new.perform(deck.id, user.id)
        expect(sourced_card.reload.source_collection_id).to be_nil
      end

      it 'does not delete the sourced card in the other deck' do
        described_class.new.perform(deck.id, user.id)
        expect(CollectionMagicCard.find_by(id: sourced_card.id)).to be_present
      end
    end

    context 'when deck has already been deleted' do
      it 'does not raise' do
        expect { described_class.new.perform(-1, user.id) }.not_to raise_error
      end

      it 'does not broadcast anything' do
        expect(Turbo::StreamsChannel).not_to receive(:broadcast_remove_to)
        expect(Turbo::StreamsChannel).not_to receive(:broadcast_append_to)
        described_class.new.perform(-1, user.id)
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
