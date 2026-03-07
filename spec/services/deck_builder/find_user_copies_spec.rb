require 'rails_helper'

RSpec.describe DeckBuilder::FindUserCopies, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let(:oracle_id) { SecureRandom.uuid }
  let(:magic_card) do
    card = create(:magic_card)
    card.update_column(:scryfall_oracle_id, oracle_id)
    card
  end

  let!(:owned_card) do
    create(:collection_magic_card,
           collection: collection,
           magic_card: magic_card,
           quantity: 3,
           foil_quantity: 1,
           staged: false,
           needed: false)
  end

  subject { described_class.call(magic_card: magic_card, user: user) }

  context 'when user has copies' do
    it 'returns the owned copies' do
      results = subject
      expect(results.count).to eq(1)
      expect(results.first.magic_card_id).to eq(magic_card.id)
    end
  end

  context 'when user has no copies' do
    before { owned_card.destroy! }

    it 'returns empty' do
      expect(subject).to be_empty
    end
  end

  context 'when oracle_id is blank' do
    let(:no_oracle_card) do
      card = create(:magic_card)
      card.update_column(:scryfall_oracle_id, nil)
      card
    end

    it 'returns empty array' do
      result = described_class.call(magic_card: no_oracle_card, user: user)
      expect(result).to eq([])
    end
  end

  context 'when user has copies of a different printing' do
    let(:alt_printing) do
      card = create(:magic_card, name: magic_card.name)
      card.update_column(:scryfall_oracle_id, oracle_id)
      card
    end

    let!(:alt_card) do
      create(:collection_magic_card,
             collection: collection,
             magic_card: alt_printing,
             quantity: 1,
             foil_quantity: 0,
             staged: false,
             needed: false)
    end

    it 'includes all printings with the same oracle id' do
      results = subject
      expect(results.count).to eq(2)
    end
  end
end
