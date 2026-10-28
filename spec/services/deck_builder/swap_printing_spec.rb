require 'rails_helper'

RSpec.describe DeckBuilder::SwapPrinting, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:oracle_id) { SecureRandom.uuid }
  let(:boxset_a) { create(:boxset) }
  let(:boxset_b) { create(:boxset) }
  let(:boxset_c) { create(:boxset) }
  let(:magic_card) { create(:magic_card, scryfall_oracle_id: oracle_id, boxset: boxset_a) }
  let(:alt_printing) { create(:magic_card, name: magic_card.name, scryfall_oracle_id: oracle_id, boxset: boxset_b) }
  let(:different_card) {
    create(:magic_card, name: 'Different Card', scryfall_oracle_id: SecureRandom.uuid, boxset: boxset_c)
  }

  let!(:deck_card) do
    create(:collection_magic_card,
           collection: deck,
           magic_card: magic_card,
           source_collection_id: nil,
           staged: true,
           staged_quantity: 1,
           staged_foil_quantity: 0,
           staged_proxy_quantity: 0,
           staged_proxy_foil_quantity: 0,
           quantity: 0,
           foil_quantity: 0)
  end

  context 'when swapping to a different printing of the same card' do
    before do
      magic_card.update_column(:scryfall_oracle_id, oracle_id)
      alt_printing.update_column(:scryfall_oracle_id, oracle_id)
    end

    subject do
      described_class.call(
        deck: deck,
        collection_magic_card_id: deck_card.id,
        new_magic_card_id: alt_printing.id
      )
    end

    it 'returns success' do
      expect(subject[:success]).to be true
      expect(subject[:card_name]).to eq(alt_printing.name)
    end

    it 'updates the magic_card_id' do
      subject
      deck_card.reload
      expect(deck_card.magic_card_id).to eq(alt_printing.id)
    end
  end

  context 'when swapping to the same printing' do
    subject do
      described_class.call(
        deck: deck,
        collection_magic_card_id: deck_card.id,
        new_magic_card_id: magic_card.id
      )
    end

    it 'returns an error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to eq('Already using this printing')
    end
  end

  context 'when swapping to a different card entirely' do
    before do
      # Ensure the oracle IDs are actually set on the magic cards
      magic_card.update_column(:scryfall_oracle_id, oracle_id)
      different_card.update_column(:scryfall_oracle_id, SecureRandom.uuid)
    end

    subject do
      described_class.call(
        deck: deck,
        collection_magic_card_id: deck_card.id,
        new_magic_card_id: different_card.id
      )
    end

    it 'returns an error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to eq('Not the same card')
    end
  end

  context 'when the staged card is pulled from a collection' do
    let(:source_collection) { create(:collection, user: user, name: 'Black Uncommons') }

    let!(:sourced_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             source_collection_id: source_collection.id,
             staged: true,
             staged_quantity: 1,
             staged_foil_quantity: 0,
             staged_proxy_quantity: 0,
             staged_proxy_foil_quantity: 0,
             quantity: 0,
             foil_quantity: 0)
    end

    before do
      create(:collection_magic_card, collection: source_collection, magic_card: magic_card, quantity: 1)
    end

    subject do
      described_class.call(
        deck: deck,
        collection_magic_card_id: sourced_card.id,
        new_magic_card_id: alt_printing.id
      )
    end

    context 'and the source does not hold the new printing' do
      it 'returns an error naming the source' do
        expect(subject[:success]).to be false
        expect(subject[:error]).to include("Black Uncommons doesn't have that printing")
      end

      it 'leaves the printing alone so finalize can still find the source' do
        subject
        expect(sourced_card.reload.magic_card_id).to eq(magic_card.id)
      end
    end

    context 'and the source holds the new printing' do
      before do
        create(:collection_magic_card, collection: source_collection, magic_card: alt_printing, quantity: 1)
      end

      it 'swaps the printing and its card_uuid' do
        expect(subject[:success]).to be true
        sourced_card.reload
        expect(sourced_card.magic_card_id).to eq(alt_printing.id)
        expect(sourced_card.card_uuid).to eq(alt_printing.card_uuid)
      end
    end

    context 'and the new printing is in the source but only as foil' do
      before do
        create(:collection_magic_card, collection: source_collection, magic_card: alt_printing,
                                       quantity: 0, foil_quantity: 1)
      end

      it 'returns an error' do
        expect(subject[:success]).to be false
        expect(subject[:error]).to include("doesn't have enough copies")
      end
    end

    context 'and the source copies of the new printing are already staged elsewhere' do
      before do
        create(:collection_magic_card, collection: source_collection, magic_card: alt_printing, quantity: 1)
        create(:collection_magic_card,
               collection: create(:collection, user: user, collection_type: 'deck'),
               magic_card: alt_printing,
               source_collection_id: source_collection.id,
               staged: true,
               staged_quantity: 1)
      end

      it 'returns an error' do
        expect(subject[:success]).to be false
        expect(subject[:error]).to include("doesn't have enough copies")
      end
    end
  end

  context 'when swapping printing on a finalized card' do
    let!(:finalized_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             staged: false,
             quantity: 1,
             foil_quantity: 0)
    end

    before do
      magic_card.update_column(:scryfall_oracle_id, oracle_id)
      alt_printing.update_column(:scryfall_oracle_id, oracle_id)
    end

    subject do
      described_class.call(
        deck: deck,
        collection_magic_card_id: finalized_card.id,
        new_magic_card_id: alt_printing.id
      )
    end

    it 'returns success' do
      expect(subject[:success]).to be true
      expect(subject[:card_name]).to eq(alt_printing.name)
    end

    it 'updates the magic_card_id' do
      subject
      finalized_card.reload
      expect(finalized_card.magic_card_id).to eq(alt_printing.id)
    end
  end

  context 'when card does not exist' do
    it 'raises RecordNotFound' do
      expect {
        described_class.call(
          deck: deck,
          collection_magic_card_id: -1,
          new_magic_card_id: alt_printing.id
        )
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
