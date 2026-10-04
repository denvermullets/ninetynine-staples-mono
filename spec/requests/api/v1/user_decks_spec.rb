require 'rails_helper'
require 'support/api/v1_helpers'

RSpec.describe 'API v1 user decks', type: :request do
  include_context 'api v1 authenticated request'

  let(:owner) { create(:user, username: 'friendly_player') }
  let(:data) { json_body['data'] }

  describe 'GET /api/v1/users/:username/decks' do
    it "returns the user's public decks, newest change first" do
      older = create(:collection, user: owner, collection_type: 'deck', updated_at: 2.days.ago)
      newer = create(:collection, user: owner, collection_type: 'commander_deck', updated_at: 1.day.ago)

      get "/api/v1/users/#{owner.username}/decks", headers: api_headers

      expect(response).to have_http_status(:ok)
      expect(data.pluck('id')).to eq([newer.id, older.id])
    end

    it 'never lists private decks' do
      shown = create(:collection, user: owner, collection_type: 'deck')
      create(:collection, user: owner, collection_type: 'commander_deck', is_public: false)

      get "/api/v1/users/#{owner.username}/decks", headers: api_headers

      expect(data.pluck('id')).to eq([shown.id])
    end

    it "lists only the named user's decks, not other collections" do
      deck = create(:collection, user: owner, collection_type: 'deck')
      create(:collection, user: owner, collection_type: 'binder')
      create(:collection, user: create(:user), collection_type: 'deck')

      get "/api/v1/users/#{owner.username}/decks", headers: api_headers

      expect(data.pluck('id')).to eq([deck.id])
    end

    it 'returns the same summary shape as GET /api/v1/decks' do
      deck = create(:collection, user: owner, name: 'Friendly Elves', collection_type: 'deck', bracket_level: 2)

      get "/api/v1/users/#{owner.username}/decks", headers: api_headers

      expect(data.first).to include(
        'id' => deck.id, 'name' => 'Friendly Elves', 'collection_type' => 'deck', 'is_public' => true,
        'bracket_level' => 2, 'card_count' => 0, 'commanders' => [], 'color_identity' => [], 'cover_image' => nil
      )
    end

    it 'matches the username case-insensitively' do
      deck = create(:collection, user: owner, collection_type: 'deck')

      get '/api/v1/users/FRIENDLY_Player/decks', headers: api_headers

      expect(data.pluck('id')).to eq([deck.id])
    end

    it 'accepts a username with a dot' do
      dotted = create(:user, username: 'jane.doe')
      deck = create(:collection, user: dotted, collection_type: 'deck')

      get '/api/v1/users/jane.doe/decks', headers: api_headers

      expect(response).to have_http_status(:ok)
      expect(data.pluck('id')).to eq([deck.id])
    end

    it 'returns an empty list for a user with no public decks' do
      create(:collection, user: owner, collection_type: 'deck', is_public: false)

      get "/api/v1/users/#{owner.username}/decks", headers: api_headers

      expect(data).to eq([])
      expect(json_body['meta']).to include('total' => 0)
    end

    it 'returns 404 for an unknown username' do
      get '/api/v1/users/nobody_here/decks', headers: api_headers

      expect_api_error(:not_found, 'not_found')
    end

    it 'paginates' do
      create_list(:collection, 3, user: owner, collection_type: 'deck')

      get "/api/v1/users/#{owner.username}/decks", params: { per_page: 2, page: 2 }, headers: api_headers

      expect(data.size).to eq(1)
      expect(json_body['meta']).to eq('page' => 2, 'per_page' => 2, 'total' => 3)
    end

    it 'rejects a request with no token' do
      get "/api/v1/users/#{owner.username}/decks", headers: { 'Accept' => 'application/json' }

      expect_api_error(:unauthorized, 'unauthorized')
    end
  end
end
