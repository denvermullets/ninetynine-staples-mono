require 'rails_helper'
require 'support/api/v1_helpers'

# The API contract: every /api/v1 response is checked against its JSON Schema in spec/support/schemas, so
# renaming or dropping a field fails here before it breaks the game client. The data is built to reach
# the optional branches of each schema - multi-face cards, rulings, tokens, null images.
RSpec.describe 'API v1 schemas', type: :request do
  include_context 'api v1 authenticated request'

  # every /api/v1 route, as "VERB path", that has an example below. A new route fails the coverage
  # check until it gets one
  let(:contract_routes) do
    ['GET /api/v1/health', 'POST /api/v1/sessions', 'DELETE /api/v1/sessions', 'GET /api/v1/me',
     'GET /api/v1/decks', 'GET /api/v1/decks/:id', 'GET /api/v1/precon_decks', 'GET /api/v1/precon_decks/:id',
     'POST /api/v1/cards/batch', 'GET /api/v1/cards/search', 'GET /api/v1/tokens',
     'GET /api/v1/users/:username/decks']
  end

  def color(name)
    Color.find_by(name: name) || create(:color, name: name)
  end

  def card(name, **attrs)
    joins = attrs.extract!(:types, :colors, :keywords)
    row = create(:magic_card, name: name, card_uuid: SecureRandom.uuid, scryfall_oracle_id: SecureRandom.uuid,
                              layout: 'normal', card_number: '1', mana_cost: '{1}{G}', mana_value: 2,
                              image_small: "https://cards.scryfall.io/small/#{name}.jpg",
                              image_medium: "https://cards.scryfall.io/normal/#{name}.jpg",
                              image_large: "https://cards.scryfall.io/large/#{name}.jpg",
                              art_crop: "https://cards.scryfall.io/art_crop/#{name}.jpg", **attrs)
    add_joins(row, **joins)
    row
  end

  def add_joins(row, types: [], colors: [], keywords: [])
    types.each { |type| row.card_types << CardType.find_or_create_by!(name: type) }
    row.colors << colors.map { |c| color(c) }
    row.color_identities << colors.map { |c| color(c) }
    keywords.each { |k| row.keywords << Keyword.find_or_create_by!(keyword: k) }
    commander = Legality.find_or_create_by!(name: 'commander')
    MagicCardLegality.create!(magic_card: row, legality: commander, status: 'Legal')
  end

  # a transform commander: two rows linked the way ingestion links them, with a ruling
  let(:commander) do
    front = card('Prowl, Stoic Strategist', card_side: 'a', layout: 'transform', can_be_commander: true,
                                            power: '3', toughness: '3', types: %w[Artifact Creature],
                                            colors: %w[W], keywords: %w[Convert], edhrec_rank: 10_287)
    back = card('Prowl, Pursuit Vehicle', card_side: 'b', layout: 'transform', mana_cost: nil, power: '2',
                                          toughness: '1', types: %w[Artifact Vehicle], art_crop: nil)
    front.update!(other_face_uuid: back.card_uuid)
    back.update!(other_face_uuid: front.card_uuid, scryfall_oracle_id: front.scryfall_oracle_id)
    front.rulings << Ruling.create!(ruling_date: '2022-10-14', ruling: 'It converts.')
    front
  end
  let(:bear) { card('Grizzly Bears', power: '2', toughness: '2', types: %w[Creature], colors: %w[G]) }
  let(:token) { card('Treasure', is_token: true, layout: 'token', mana_cost: nil, types: %w[Token Artifact]) }

  let(:deck) do
    create(:collection, user: api_user, collection_type: 'commander_deck', bracket_level: 3).tap do |deck|
      create(:collection_magic_card, collection: deck, magic_card: commander, board_type: 'commander')
      create(:collection_magic_card, collection: deck, magic_card: bear, quantity: 2)
      create(:collection_magic_card, collection: deck, magic_card: bear, board_type: 'sideboard')
    end
  end

  let(:precon) do
    create(:precon_deck, deck_type: 'Commander Deck', release_date: nil).tap do |precon|
      { 'commander' => commander, 'mainBoard' => bear, 'tokens' => token }.each do |board, row|
        PreconDeckCard.create!(precon_deck: precon, magic_card: row, board_type: board, quantity: 1)
      end
    end
  end

  def post_json(path, body, headers: api_headers)
    post path, params: body.to_json, headers: headers.merge('Content-Type' => 'application/json')
  end

  it 'has an example for every /api/v1 route' do
    routes = Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s.delete_suffix('(.:format)')
      "#{route.verb} #{path}" if path.start_with?('/api/v1/') && !path.include?('*')
    end

    expect(routes).to match_array(contract_routes)
  end

  it 'every schema file is a valid JSON Schema' do
    ApiSchemas.names.each do |name|
      expect(ApiSchemas.schema(name).valid_schema?).to be(true), "#{name}.json is not a valid schema"
    end
  end

  describe 'success responses' do
    it 'GET /health matches health.json' do
      get '/api/v1/health'
      expect(json_body).to match_api_schema(:health)
    end

    it 'POST /sessions matches session.json' do
      create(:user, email: 'player@example.com', password: 'correct-horse')
      post_json '/api/v1/sessions', { email: 'player@example.com', password: 'correct-horse' }, headers: {}

      expect(response).to have_http_status(:created)
      expect(json_body).to match_api_schema(:session)
    end

    it 'DELETE /sessions has no body' do
      delete '/api/v1/sessions', headers: api_headers

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
    end

    it 'GET /me matches user.json with preferences' do
      get '/api/v1/me', headers: api_headers

      expect(json_body).to match_api_schema(:user)
      expect(json_body).to have_key('preferences')
    end

    it 'GET /decks is a page of deck_summary.json' do
      deck
      create(:collection, user: api_user, collection_type: 'deck', bracket_level: nil)
      get '/api/v1/decks', headers: api_headers

      expect(json_body['data'].size).to eq(2)
      expect(json_body).to match_api_page_of(:deck_summary)
    end

    it 'GET /decks/:id matches deck.json, with rulings' do
      get "/api/v1/decks/#{deck.id}", params: { include: 'rulings' }, headers: api_headers

      expect(json_body['cards'].pluck('board')).to eq(%w[commander mainboard sideboard])
      expect(json_body['cards'].first['card']['faces'].size).to eq(2)
      expect(json_body['cards'].first['card']['rulings']).to be_present
      expect(json_body).to match_api_schema(:deck)
    end

    it 'GET /users/:username/decks is a page of deck_summary.json' do
      deck
      get "/api/v1/users/#{api_user.username}/decks", headers: api_headers

      expect(json_body['data']).to be_present
      expect(json_body).to match_api_page_of(:deck_summary)
    end

    it 'GET /precon_decks is a page of precon_deck_summary.json' do
      precon
      get '/api/v1/precon_decks', headers: api_headers

      expect(json_body['data']).to be_present
      expect(json_body).to match_api_page_of(:precon_deck_summary)
    end

    it 'GET /precon_decks/:id matches deck.json, with tokens' do
      get "/api/v1/precon_decks/#{precon.id}", headers: api_headers

      expect(json_body['tokens']).to be_present
      expect(json_body).to match_api_schema(:deck)
    end

    it 'POST /cards/batch matches card_batch.json' do
      post_json '/api/v1/cards/batch', { oracle_ids: [commander.scryfall_oracle_id, SecureRandom.uuid] }

      expect(json_body['cards']).to be_present
      expect(json_body['missing']).to be_present
      expect(json_body).to match_api_schema(:card_batch)
    end

    it 'GET /cards/search is a page of card_summary.json' do
      bear
      get '/api/v1/cards/search', params: { q: 'bear' }, headers: api_headers

      expect(json_body['data']).to be_present
      expect(json_body).to match_api_page_of(:card_summary)
    end

    it 'GET /tokens is a page of card.json' do
      token
      get '/api/v1/tokens', params: { include: 'rulings' }, headers: api_headers

      expect(json_body['data']).to be_present
      expect(json_body).to match_api_page_of(:card)
    end
  end

  describe 'error responses match error.json' do
    it 'for a missing token' do
      get '/api/v1/decks'
      expect_api_error(:unauthorized, 'unauthorized')
    end

    it 'for wrong credentials' do
      post_json '/api/v1/sessions', { email: 'nobody@example.com', password: 'nope' }, headers: {}
      expect_api_error(:unauthorized, 'invalid_credentials')
    end

    it 'for an unknown record and an unknown path' do
      get '/api/v1/decks/0', headers: api_headers
      expect_api_error(:not_found, 'not_found')

      get '/api/v1/nope', headers: api_headers
      expect_api_error(:not_found, 'not_found')
    end

    it 'for bad batch parameters' do
      post_json '/api/v1/cards/batch', {}
      expect_api_error(:unprocessable_content, 'parameter_missing')

      post_json '/api/v1/cards/batch', { oracle_ids: ['a'], card_uuids: ['b'] }
      expect_api_error(:unprocessable_content, 'invalid_parameter')

      post_json '/api/v1/cards/batch', { oracle_ids: Array.new(201) { SecureRandom.uuid } }
      expect_api_error(:unprocessable_content, 'too_many_ids')
    end
  end
end
