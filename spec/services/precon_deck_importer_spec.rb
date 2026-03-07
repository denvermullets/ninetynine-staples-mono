require 'rails_helper'

RSpec.describe PreconDeckImporter, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user, collection_type: 'deck') }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0) }
  let(:foil_card) { create(:magic_card, normal_price: 3.0, foil_price: 8.0) }

  let(:precon_deck) { PreconDeck.create!(code: 'TST', file_name: 'test_precon', name: 'Test Precon') }

  before do
    PreconDeckCard.create!(
      precon_deck: precon_deck, magic_card: magic_card,
      board_type: 'mainBoard', quantity: 4, is_foil: false
    )
    PreconDeckCard.create!(
      precon_deck: precon_deck, magic_card: foil_card,
      board_type: 'commander', quantity: 1, is_foil: true
    )
  end

  subject { described_class.call(precon_deck: precon_deck, collection: collection) }

  it 'returns success with card count' do
    result = subject
    expect(result[:action]).to eq(:success)
    expect(result[:cards_imported]).to eq(2)
  end

  it 'creates collection magic cards' do
    expect { subject }.to change { collection.collection_magic_cards.count }.by(2)
  end

  it 'sets regular quantity for non-foil cards' do
    subject
    cmc = collection.collection_magic_cards.find_by(magic_card: magic_card)
    expect(cmc.quantity).to eq(4)
    expect(cmc.foil_quantity).to eq(0)
  end

  it 'sets foil quantity for foil cards' do
    subject
    cmc = collection.collection_magic_cards.find_by(magic_card: foil_card)
    expect(cmc.quantity).to eq(0)
    expect(cmc.foil_quantity).to eq(1)
  end

  it 'maps board types correctly' do
    subject
    cmc = collection.collection_magic_cards.find_by(magic_card: foil_card)
    expect(cmc.board_type).to eq('commander')
  end

  it 'updates collection totals' do
    subject
    collection.reload
    expect(collection.total_quantity).to eq(4)
    expect(collection.total_foil_quantity).to eq(1)
  end

  context 'when importing twice (idempotent quantities)' do
    it 'increments quantities' do
      described_class.call(precon_deck: precon_deck, collection: collection)
      described_class.call(precon_deck: precon_deck, collection: collection)

      cmc = collection.collection_magic_cards.find_by(magic_card: magic_card)
      expect(cmc.quantity).to eq(8)
    end
  end
end
