require 'rails_helper'

RSpec.describe DeckBuilder::Search, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:other_collection) { create(:collection, user: user) }
  let(:magic_card) { create(:magic_card, name: 'Lightning Bolt', is_token: false, card_uuid: 'bolt-uuid') }

  let!(:owned_card) do
    create(:collection_magic_card,
           collection: other_collection,
           magic_card: magic_card,
           quantity: 4,
           foil_quantity: 1,
           staged: false,
           needed: false)
  end

  subject do
    described_class.call(
      query: query,
      user: user,
      deck: deck,
      scope: scope,
      limit: 20
    )
  end

  context 'with a matching owned card' do
    let(:query) { 'Lightning' }
    let(:scope) { 'owned' }

    it 'returns owned card results' do
      results = subject
      expect(results).not_to be_empty
      expect(results.first[:type]).to eq(:owned)
      expect(results.first[:card]).to eq(magic_card)
    end

    it 'includes collection info' do
      results = subject
      expect(results.first[:collection_name]).to eq(other_collection.name)
    end
  end

  context 'with scope all' do
    let(:query) { 'Lightning' }
    let(:scope) { 'all' }

    it 'returns results' do
      results = subject
      expect(results).not_to be_empty
    end
  end

  context 'with a blank query' do
    let(:query) { '' }
    let(:scope) { 'all' }

    it 'returns empty array' do
      expect(subject).to eq([])
    end
  end

  context 'with a too-short query' do
    let(:query) { 'L' }
    let(:scope) { 'all' }

    it 'returns empty array' do
      expect(subject).to eq([])
    end
  end

  context 'when card is already in deck' do
    let(:query) { 'Lightning' }
    let(:scope) { 'owned' }

    before do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             source_collection_id: other_collection.id,
             staged: true,
             staged_quantity: 1,
             quantity: 0,
             foil_quantity: 0)
    end

    it 'marks the card as already_in_deck' do
      results = subject
      expect(results.first[:already_in_deck]).to be true
    end
  end
end
