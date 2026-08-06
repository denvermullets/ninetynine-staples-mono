require 'rails_helper'

RSpec.describe PreconDeckCard, type: :model do
  let(:precon_deck) { PreconDeck.create!(code: 'TST', file_name: 'test_deck', name: 'Test Deck') }

  def build_card(magic_card:, is_foil: false, quantity: 1)
    described_class.create!(
      precon_deck: precon_deck, magic_card: magic_card,
      board_type: 'mainBoard', is_foil: is_foil, quantity: quantity
    )
  end

  describe '#unit_price' do
    it 'uses normal_price for non-foil cards' do
      card = build_card(magic_card: create(:magic_card, normal_price: 5.0, foil_price: 10.0))
      expect(card.unit_price).to eq(5.0)
    end

    it 'uses foil_price for foil cards' do
      card = build_card(magic_card: create(:magic_card, normal_price: 5.0, foil_price: 10.0), is_foil: true)
      expect(card.unit_price).to eq(10.0)
    end

    it 'falls back to normal_price when a foil card has no foil price' do
      card = build_card(magic_card: create(:magic_card, normal_price: 5.0, foil_price: 0.0), is_foil: true)
      expect(card.unit_price).to eq(5.0)
    end

    it 'falls back to foil_price when a non-foil card has no normal price' do
      card = build_card(magic_card: create(:magic_card, normal_price: 0.0, foil_price: 15.0))
      expect(card.unit_price).to eq(15.0)
    end

    it 'returns zero when the card has no price data' do
      card = build_card(magic_card: create(:magic_card, normal_price: 0.0, foil_price: 0.0))
      expect(card.unit_price).to eq(0.0)
    end
  end

  describe '#value' do
    it 'multiplies quantity by the unit price' do
      card = build_card(magic_card: create(:magic_card, normal_price: 5.0, foil_price: 10.0), quantity: 3)
      expect(card.value).to eq(15.0)
    end

    it 'prices foil copies at the foil price' do
      card = build_card(
        magic_card: create(:magic_card, normal_price: 5.0, foil_price: 10.0), is_foil: true, quantity: 3
      )
      expect(card.value).to eq(30.0)
    end
  end
end
