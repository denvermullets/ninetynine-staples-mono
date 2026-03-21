require 'rails_helper'

RSpec.describe DeckBuilder::ChangeCardType, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 15.0) }

  let!(:deck_card) do
    create(:collection_magic_card,
           collection: deck,
           magic_card: magic_card,
           staged: false,
           quantity: 1,
           foil_quantity: 0,
           proxy_quantity: 0,
           proxy_foil_quantity: 0)
  end

  context 'when changing a regular card to foil' do
    subject { described_class.call(deck: deck, card_id: deck_card.id, card_type: 'foil') }

    it 'returns success' do
      expect(subject[:success]).to be true
      expect(subject[:card_type]).to eq('foil')
    end

    it 'moves quantity to foil' do
      subject
      deck_card.reload
      expect(deck_card.quantity).to eq(0)
      expect(deck_card.foil_quantity).to eq(1)
      expect(deck_card.proxy_quantity).to eq(0)
      expect(deck_card.proxy_foil_quantity).to eq(0)
    end

    it 'recalculates deck totals' do
      expect(Collections::UpdateTotals).to receive(:call).with(collection: deck)
      subject
    end
  end

  context 'when changing a foil card to proxy' do
    before { deck_card.update!(quantity: 0, foil_quantity: 1) }

    subject { described_class.call(deck: deck, card_id: deck_card.id, card_type: 'proxy') }

    it 'moves quantity to proxy' do
      subject
      deck_card.reload
      expect(deck_card.quantity).to eq(0)
      expect(deck_card.foil_quantity).to eq(0)
      expect(deck_card.proxy_quantity).to eq(1)
      expect(deck_card.proxy_foil_quantity).to eq(0)
    end
  end

  context 'when changing to proxy_foil' do
    subject { described_class.call(deck: deck, card_id: deck_card.id, card_type: 'proxy_foil') }

    it 'moves quantity to proxy_foil' do
      subject
      deck_card.reload
      expect(deck_card.quantity).to eq(0)
      expect(deck_card.foil_quantity).to eq(0)
      expect(deck_card.proxy_quantity).to eq(0)
      expect(deck_card.proxy_foil_quantity).to eq(1)
    end
  end

  context 'when card is already the target type' do
    subject { described_class.call(deck: deck, card_id: deck_card.id, card_type: 'regular') }

    it 'returns an error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to eq('Already this type')
    end
  end

  context 'when card type is invalid' do
    subject { described_class.call(deck: deck, card_id: deck_card.id, card_type: 'mythic') }

    it 'returns an error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to eq('Invalid card type')
    end
  end

  context 'when card has mixed quantities' do
    before { deck_card.update!(quantity: 1, foil_quantity: 1) }

    subject { described_class.call(deck: deck, card_id: deck_card.id, card_type: 'foil') }

    it 'moves total display_quantity to target type' do
      subject
      deck_card.reload
      expect(deck_card.quantity).to eq(0)
      expect(deck_card.foil_quantity).to eq(2)
    end
  end

  context 'when card is staged' do
    let!(:staged_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             staged: true,
             staged_quantity: 1,
             staged_foil_quantity: 0,
             staged_proxy_quantity: 0,
             staged_proxy_foil_quantity: 0,
             quantity: 0,
             foil_quantity: 0,
             proxy_quantity: 0,
             proxy_foil_quantity: 0)
    end

    subject { described_class.call(deck: deck, card_id: staged_card.id, card_type: 'foil') }

    it 'does not recalculate totals' do
      expect(Collections::UpdateTotals).not_to receive(:call)
      subject
    end
  end

  context 'when card does not exist' do
    it 'raises RecordNotFound' do
      expect {
        described_class.call(deck: deck, card_id: -1, card_type: 'foil')
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
