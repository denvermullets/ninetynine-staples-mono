require 'rails_helper'

RSpec.describe DeckBuilder::FindAvailableSources, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:collection_a) { create(:collection, user: user, name: 'Collection A') }
  let(:magic_card) do
    card = create(:magic_card)
    card.update_column(:scryfall_oracle_id, SecureRandom.uuid)
    card
  end

  let!(:staged_card) do
    create(:collection_magic_card,
           collection: deck,
           magic_card: magic_card,
           source_collection_id: collection_a.id,
           staged: true,
           staged_quantity: 1,
           staged_foil_quantity: 0,
           staged_proxy_quantity: 0,
           staged_proxy_foil_quantity: 0,
           quantity: 0,
           foil_quantity: 0)
  end

  let!(:source_card) do
    create(:collection_magic_card,
           collection: collection_a,
           magic_card: magic_card,
           quantity: 3,
           foil_quantity: 0,
           staged: false,
           needed: false)
  end

  subject { described_class.call(card: staged_card, user: user, deck: deck) }

  context 'when user has copies in other collections' do
    it 'returns available sources' do
      results = subject
      expect(results).not_to be_empty
      expect(results.first[:collection_name]).to eq('Collection A')
    end

    it 'marks the current source' do
      results = subject
      expect(results.first[:is_current]).to be true
    end
  end

  context 'when source does not have enough copies' do
    before { source_card.update!(quantity: 0) }

    it 'excludes insufficient sources' do
      results = subject
      expect(results).to be_empty
    end
  end
end
