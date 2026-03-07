require 'rails_helper'

RSpec.describe DeckBuilder::LoadCards, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0, card_type: 'Creature') }

  subject { described_class.call(deck: deck, grouping: 'type', sort_by: 'mana_value') }

  context 'with no cards in the deck' do
    it 'returns empty collections' do
      result = subject
      expect(result[:staged_cards]).to be_empty
      expect(result[:needed_cards]).to be_empty
      expect(result[:owned_cards]).to be_empty
    end

    it 'returns zero stats' do
      result = subject
      expect(result[:stats][:total]).to eq(0)
    end
  end

  context 'with mixed card states' do
    let(:source_collection) { create(:collection, user: user) }

    let!(:staged_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             source_collection_id: source_collection.id,
             staged: true,
             staged_quantity: 2,
             staged_foil_quantity: 0,
             staged_proxy_quantity: 0,
             staged_proxy_foil_quantity: 0,
             quantity: 0,
             foil_quantity: 0)
    end

    let!(:owned_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: create(:magic_card, normal_price: 3.0, foil_price: 6.0, card_type: 'Instant',
                                             boxset: create(:boxset)),
             staged: false,
             needed: false,
             quantity: 3,
             foil_quantity: 1)
    end

    let!(:needed_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: create(:magic_card, normal_price: 1.0, foil_price: 2.0, card_type: 'Sorcery',
                                             boxset: create(:boxset)),
             staged: false,
             needed: true,
             quantity: 1,
             foil_quantity: 0)
    end

    it 'categorizes cards correctly' do
      result = subject
      expect(result[:staged_cards].count).to eq(1)
      expect(result[:owned_cards].count).to eq(1)
      expect(result[:needed_cards].count).to eq(1)
    end

    it 'calculates stats' do
      result = subject
      expect(result[:stats][:staged]).to eq(2)
      expect(result[:stats][:owned]).to eq(4) # 3 + 1
      expect(result[:stats][:needed]).to eq(1)
    end

    it 'groups cards' do
      result = subject
      expect(result[:grouped_cards]).to be_a(Hash)
      expect(result[:grouped_cards]).not_to be_empty
    end
  end
end
