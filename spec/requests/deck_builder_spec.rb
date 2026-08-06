require 'rails_helper'

RSpec.describe 'DeckBuilder', type: :request do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }

  let(:alpha) { create(:magic_card, name: 'Alpha Strike', mana_value: 6, boxset: create(:boxset)) }
  let(:zeta) { create(:magic_card, name: 'Zeta Bolt', mana_value: 1, boxset: create(:boxset)) }
  let(:doomed) { create(:magic_card, name: 'Doomed Card', mana_value: 3, boxset: create(:boxset)) }

  # Staged cards, since remove_card only applies to cards still in build mode
  let!(:cmc_alpha) do
    create(:collection_magic_card, collection: deck, magic_card: alpha, staged: true, staged_quantity: 1)
  end
  let!(:cmc_zeta) do
    create(:collection_magic_card, collection: deck, magic_card: zeta, staged: true, staged_quantity: 1)
  end
  let!(:cmc_doomed) do
    create(:collection_magic_card, collection: deck, magic_card: doomed, staged: true, staged_quantity: 1)
  end

  before { post login_path, params: { email: user.email, password: 'password123' } }

  # Sorting by name puts Alpha first; the default mana_value sort puts Zeta first,
  # so the resulting order tells us which sort the server actually applied.
  def rendered_order
    response.body.scan(/Alpha Strike|Zeta Bolt/).uniq
  end

  describe 'DELETE /deck-builder/:id/remove_card' do
    it 'keeps the requested sort order when a card is removed' do
      delete remove_card_deck_builder_path(deck, card_id: cmc_doomed.id, sort_by: 'name', grouping: 'none'),
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(rendered_order).to eq(['Alpha Strike', 'Zeta Bolt'])
    end

    it 'falls back to the default sort when none is given' do
      delete remove_card_deck_builder_path(deck, card_id: cmc_doomed.id, grouping: 'none'),
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(rendered_order).to eq(['Zeta Bolt', 'Alpha Strike'])
    end
  end

  describe 'GET /deck-builder/:id/transfer_card_modal' do
    it 'carries the view state into the actions the modal submits to' do
      get transfer_card_modal_deck_builder_path(deck, card_id: cmc_doomed.id, sort_by: 'name', grouping: 'none')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('sort_by=name')
      expect(response.body).to include('grouping=none')
    end
  end
end
