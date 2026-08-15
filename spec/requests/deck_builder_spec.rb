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
  # Renders a bare partial, never the layout - a request spec that renders deck_builder/show needs a
  # built tailwind.css, which CI does not have. What the panel shows is covered by the service spec.
  describe 'GET /suggestions' do
    let(:commander_legality) { Legality.find_or_create_by!(name: 'commander') }

    let(:commander) do
      card = create(:magic_card, name: 'The Commander', scryfall_oracle_id: SecureRandom.uuid,
                                 card_side: nil, can_be_commander: true,
                                 card_type: 'Legendary Creature - Elf',
                                 text: 'Sacrifice another creature: draw a card.')
      create(:card_role, scryfall_oracle_id: card.scryfall_oracle_id, role: 'sacrifice',
                         effect: 'sacrifice_outlet', confidence: 0.9)
      card
    end

    def set_commander!
      create(:collection_magic_card, collection: deck, magic_card: commander, board_type: 'commander')
    end

    it 'renders the empty state when the deck has no commander' do
      get suggestions_deck_builder_path(deck)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Set a commander on this deck')
    end

    it 'renders the suggestions frame for a deck with a commander' do
      set_commander!
      suggestion = create(:magic_card, name: 'Spicy Sac Outlet', scryfall_oracle_id: SecureRandom.uuid,
                                       card_side: nil, edhrec_rank: 2500, boxset: create(:boxset))
      MagicCardLegality.find_or_create_by!(magic_card: suggestion, legality: commander_legality, status: 'Legal')
      create(:card_role, scryfall_oracle_id: suggestion.scryfall_oracle_id, role: 'sacrifice',
                         effect: 'sacrifice_outlet', confidence: 0.9)

      get suggestions_deck_builder_path(deck)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<turbo-frame id="deck_suggestions"')
      expect(response.body).to include('Spicy Sac Outlet')
    end

    it 'narrows to one role when the role filter is used' do
      set_commander!

      get suggestions_deck_builder_path(deck, role: 'ramp')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('role=ramp')
    end

    it 'refuses a deck the current user does not own' do
      other_deck = create(:collection, user: create(:user), collection_type: 'deck')

      get suggestions_deck_builder_path(other_deck)

      expect(response).not_to have_http_status(:ok)
    end
  end
end
