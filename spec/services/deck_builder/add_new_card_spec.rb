require 'rails_helper'

RSpec.describe DeckBuilder::AddNewCard, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:magic_card) { create(:magic_card, card_uuid: 'test-uuid', normal_price: 5.0, foil_price: 10.0) }

  subject do
    described_class.call(
      deck: deck,
      magic_card_id: magic_card.id,
      card_type: card_type,
      quantity: quantity
    )
  end

  context 'when adding a regular card' do
    let(:card_type) { 'regular' }
    let(:quantity) { 2 }

    it 'creates an owned card in the deck' do
      expect { subject }.to change { deck.collection_magic_cards.count }.by(1)
    end

    it 'returns success' do
      expect(subject[:success]).to be true
      expect(subject[:card_name]).to eq(magic_card.name)
    end

    it 'sets quantity correctly' do
      result = subject
      expect(result[:card].quantity).to eq(2)
      expect(result[:card].staged).to be false
      expect(result[:card].needed).to be false
    end

    it 'updates collection totals' do
      subject
      deck.reload
      expect(deck.total_quantity).to eq(2)
      expect(deck.total_value).to eq(2 * 5.0)
    end
  end

  context 'when adding a foil card' do
    let(:card_type) { 'foil' }
    let(:quantity) { 1 }

    it 'sets foil_quantity correctly' do
      result = subject
      expect(result[:card].foil_quantity).to eq(1)
    end

    it 'updates foil totals' do
      subject
      deck.reload
      expect(deck.total_foil_quantity).to eq(1)
      expect(deck.total_value).to eq(1 * 10.0)
    end
  end

  context 'when adding a proxy card' do
    let(:card_type) { 'proxy' }
    let(:quantity) { 3 }

    it 'sets proxy_quantity correctly' do
      result = subject
      expect(result[:card].proxy_quantity).to eq(3)
    end

    it 'updates proxy totals' do
      subject
      deck.reload
      expect(deck.total_proxy_quantity).to eq(3)
    end
  end

  context 'when adding a foil proxy card' do
    let(:card_type) { 'foil_proxy' }
    let(:quantity) { 1 }

    it 'sets proxy_foil_quantity correctly' do
      result = subject
      expect(result[:card].proxy_foil_quantity).to eq(1)
    end
  end

  context 'when adding to an existing owned card' do
    let(:card_type) { 'regular' }
    let(:quantity) { 2 }
    let!(:existing_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             quantity: 1,
             foil_quantity: 0,
             staged: false,
             needed: false)
    end

    it 'does not create a new record' do
      expect { subject }.not_to(change { CollectionMagicCard.count })
    end

    it 'increments the quantity' do
      result = subject
      expect(result[:card].quantity).to eq(3)
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

  context 'when card does not exist' do
    it 'raises RecordNotFound' do
      expect {
        described_class.call(deck: deck, magic_card_id: -1, card_type: 'regular', quantity: 1)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
