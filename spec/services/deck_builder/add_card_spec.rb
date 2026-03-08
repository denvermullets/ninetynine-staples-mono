require 'rails_helper'

RSpec.describe DeckBuilder::AddCard, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:source_collection) { create(:collection, user: user) }
  let(:magic_card) { create(:magic_card, card_uuid: 'test-uuid') }
  let!(:source_card) do
    create(:collection_magic_card,
           collection: source_collection,
           magic_card: magic_card,
           quantity: 4,
           foil_quantity: 2,
           proxy_quantity: 1,
           proxy_foil_quantity: 1,
           staged: false,
           needed: false)
  end

  subject do
    described_class.call(
      deck: deck,
      magic_card_id: magic_card.id,
      source_collection_id: source_collection.id,
      card_type: card_type,
      quantity: quantity
    )
  end

  context 'when adding a regular card from a source collection' do
    let(:card_type) { 'regular' }
    let(:quantity) { 2 }

    it 'creates a staged card in the deck' do
      expect { subject }.to change { deck.collection_magic_cards.staged.count }.by(1)
    end

    it 'returns success' do
      expect(subject[:success]).to be true
      expect(subject[:card_name]).to eq(magic_card.name)
    end

    it 'sets the staged_quantity correctly' do
      result = subject
      staged_card = result[:card]
      expect(staged_card.staged_quantity).to eq(2)
      expect(staged_card.staged).to be true
      expect(staged_card.source_collection_id).to eq(source_collection.id)
    end
  end

  context 'when adding a foil card' do
    let(:card_type) { 'foil' }
    let(:quantity) { 1 }

    it 'sets the staged_foil_quantity' do
      result = subject
      expect(result[:card].staged_foil_quantity).to eq(1)
    end
  end

  context 'when adding a proxy card' do
    let(:card_type) { 'proxy' }
    let(:quantity) { 1 }

    it 'sets the staged_proxy_quantity' do
      result = subject
      expect(result[:card].staged_proxy_quantity).to eq(1)
    end
  end

  context 'when adding a proxy_foil card' do
    let(:card_type) { 'proxy_foil' }
    let(:quantity) { 1 }

    it 'sets the staged_proxy_foil_quantity' do
      result = subject
      expect(result[:card].staged_proxy_foil_quantity).to eq(1)
    end
  end

  context 'when adding to an existing staged card' do
    let(:card_type) { 'regular' }
    let(:quantity) { 1 }
    let!(:existing_staged) do
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

    it 'does not create a new record' do
      expect { subject }.not_to(change { CollectionMagicCard.count })
    end

    it 'increments the staged quantity' do
      result = subject
      expect(result[:card].staged_quantity).to eq(2)
    end
  end

  context 'when source does not have enough cards' do
    let(:card_type) { 'regular' }
    let(:quantity) { 10 }

    it 'returns an error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to include('available')
    end
  end

  context 'with an invalid card type' do
    let(:card_type) { 'invalid' }
    let(:quantity) { 1 }

    it 'returns an error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to eq('Invalid card type')
    end
  end

  context 'with zero quantity' do
    let(:card_type) { 'regular' }
    let(:quantity) { 0 }

    it 'returns an error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to eq('No quantity specified')
    end
  end

  context 'without a source collection (planned card)' do
    let(:card_type) { 'regular' }
    let(:quantity) { 1 }

    subject do
      described_class.call(
        deck: deck,
        magic_card_id: magic_card.id,
        source_collection_id: nil,
        card_type: card_type,
        quantity: quantity
      )
    end

    it 'creates a staged card without a source' do
      result = subject
      expect(result[:success]).to be true
      expect(result[:card].source_collection_id).to be_nil
      expect(result[:card].staged).to be true
    end
  end

  context 'when card does not exist' do
    it 'raises RecordNotFound' do
      expect {
        described_class.call(
          deck: deck,
          magic_card_id: -1,
          source_collection_id: source_collection.id,
          card_type: 'regular',
          quantity: 1
        )
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
