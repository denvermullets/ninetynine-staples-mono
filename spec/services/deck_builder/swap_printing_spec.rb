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
