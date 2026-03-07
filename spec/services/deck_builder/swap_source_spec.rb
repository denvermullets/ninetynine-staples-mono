require 'rails_helper'

RSpec.describe DeckBuilder::SwapSource, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:source_a) { create(:collection, user: user, name: 'Collection A') }
  let(:source_b) { create(:collection, user: user, name: 'Collection B') }
  let(:magic_card) { create(:magic_card) }

  let!(:source_a_card) do
    create(:collection_magic_card,
           collection: source_a,
           magic_card: magic_card,
           quantity: 2,
           foil_quantity: 0,
           staged: false,
           needed: false)
  end

  let!(:source_b_card) do
    create(:collection_magic_card,
           collection: source_b,
           magic_card: magic_card,
           quantity: 3,
           foil_quantity: 1,
           staged: false,
           needed: false)
  end

  let!(:staged_card) do
    create(:collection_magic_card,
           collection: deck,
           magic_card: magic_card,
           source_collection_id: source_a.id,
           staged: true,
           staged_quantity: 1,
           staged_foil_quantity: 0,
           staged_proxy_quantity: 0,
           staged_proxy_foil_quantity: 0,
           quantity: 0,
           foil_quantity: 0)
  end

  context 'when swapping to a different source' do
    subject do
      described_class.call(
        deck: deck,
        collection_magic_card_id: staged_card.id,
        new_source_collection_id: source_b.id
      )
    end

    it 'returns success' do
      expect(subject[:success]).to be true
      expect(subject[:source_name]).to eq('Collection B')
    end

    it 'updates the source_collection_id' do
      subject
      staged_card.reload
      expect(staged_card.source_collection_id).to eq(source_b.id)
    end
  end

  context 'when swapping to the same source' do
    subject do
      described_class.call(
        deck: deck,
        collection_magic_card_id: staged_card.id,
        new_source_collection_id: source_a.id
      )
    end

    it 'returns an error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to eq('Already using this source')
    end
  end

  context 'when swapping to planned (no source)' do
    subject do
      described_class.call(
        deck: deck,
        collection_magic_card_id: staged_card.id,
        new_source_collection_id: nil
      )
    end

    it 'returns success' do
      expect(subject[:success]).to be true
      expect(subject[:source_name]).to eq('planned')
    end

    it 'sets source_collection_id to nil' do
      subject
      staged_card.reload
      expect(staged_card.source_collection_id).to be_nil
    end
  end

  context 'when new source does not have enough cards' do
    before do
      source_b_card.update!(quantity: 0, foil_quantity: 0, proxy_quantity: 0, proxy_foil_quantity: 0)
    end

    subject do
      described_class.call(
        deck: deck,
        collection_magic_card_id: staged_card.id,
        new_source_collection_id: source_b.id
      )
    end

    it 'returns an error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to include('available')
    end
  end

  context 'when swapping source with a new printing' do
    let(:alt_boxset) { create(:boxset) }
    let(:alt_printing) { create(:magic_card, scryfall_oracle_id: magic_card.scryfall_oracle_id, boxset: alt_boxset) }

    let!(:source_b_alt) do
      create(:collection_magic_card,
             collection: source_b,
             magic_card: alt_printing,
             quantity: 2,
             foil_quantity: 0,
             staged: false,
             needed: false)
    end

    subject do
      described_class.call(
        deck: deck,
        collection_magic_card_id: staged_card.id,
        new_source_collection_id: source_b.id,
        new_magic_card_id: alt_printing.id
      )
    end

    it 'updates both source and magic_card' do
      subject
      staged_card.reload
      expect(staged_card.source_collection_id).to eq(source_b.id)
      expect(staged_card.magic_card_id).to eq(alt_printing.id)
    end
  end
end
