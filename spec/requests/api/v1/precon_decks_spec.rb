require 'rails_helper'
require 'support/api/v1_helpers'

RSpec.describe 'API v1 precon decks', type: :request do
  include_context 'api v1 authenticated request'

  def color(name)
    Color.find_by(name: name) || create(:color, name: name)
  end

  def commander_card(name, identity:)
    create(:magic_card, name: name, card_uuid: SecureRandom.uuid, scryfall_oracle_id: SecureRandom.uuid,
                        art_crop: "https://cards.scryfall.io/art_crop/#{name}.jpg",
                        image_medium: "https://cards.scryfall.io/normal/#{name}.jpg",
                        color_identities: identity.map { |c| color(c) })
  end

  def add_card(deck, card = create(:magic_card), board_type: 'mainBoard', quantity: 1, **attrs)
    PreconDeckCard.create!(precon_deck: deck, magic_card: card, board_type: board_type, quantity: quantity, **attrs)
  end

  # a Commander precon with its commander
  def precon(**attrs)
    create(:precon_deck, deck_type: 'Commander Deck', **attrs).tap { |deck| add_card(deck, board_type: 'commander') }
  end

  let(:data) { json_body['data'] }

  describe 'GET /api/v1/precon_decks' do
    it 'lists only Commander precons that have a commander' do
      commander = precon
      precon(deck_type: 'Brawl Deck')
      add_card(create(:precon_deck, deck_type: 'Theme Deck'))
      add_card(create(:precon_deck, deck_type: 'Commander Deck'))

      get '/api/v1/precon_decks', headers: api_headers

      expect(response).to have_http_status(:ok)
      expect(data.pluck('id')).to eq([commander.id])
    end

    it 'searches by name' do
      turtles = precon(name: 'Turtle Power!')
      precon(name: 'Mutant Menace')

      get '/api/v1/precon_decks', params: { q: 'turtle' }, headers: api_headers

      expect(data.pluck('id')).to eq([turtles.id])
    end

    it 'treats LIKE wildcards in q literally' do
      precon(name: 'Turtle Power!')

      get '/api/v1/precon_decks', params: { q: '%' }, headers: api_headers

      expect(data).to eq([])
    end

    it 'lists the newest release first' do
      older = precon(release_date: 1.year.ago.to_date)
      newer = precon(release_date: 1.week.ago.to_date)

      get '/api/v1/precon_decks', headers: api_headers

      expect(data.pluck('id')).to eq([newer.id, older.id])
    end

    it 'returns the precon summary with its commander' do
      deck = create(:precon_deck, name: 'Turtle Power!', code: 'TMC', deck_type: 'Commander Deck',
                                  release_date: Date.new(2026, 3, 6))
      leader = commander_card('Heroes', identity: %w[G R W])
      add_card(deck, leader, board_type: 'commander')
      add_card(deck, quantity: 99)
      add_card(deck, board_type: 'sideBoard')
      add_card(deck, board_type: 'tokens', quantity: 3)

      get '/api/v1/precon_decks', headers: api_headers

      expect(data.first).to include(
        'id' => deck.id, 'name' => 'Turtle Power!', 'code' => 'TMC', 'release_date' => '2026-03-06',
        'card_count' => 100, 'color_identity' => %w[W R G],
        'cover_image' => 'https://cards.scryfall.io/art_crop/Heroes.jpg'
      )
      expect(data.first['commanders']).to eq([{
                                               'card_uuid' => leader.card_uuid,
                                               'oracle_id' => leader.scryfall_oracle_id,
                                               'name' => 'Heroes',
                                               'image_art_crop' => 'https://cards.scryfall.io/art_crop/Heroes.jpg',
                                               'image_normal' => 'https://cards.scryfall.io/normal/Heroes.jpg'
                                             }])
    end

    it 'paginates' do
      3.times { precon }

      get '/api/v1/precon_decks', params: { per_page: 2, page: 2 }, headers: api_headers

      expect(data.size).to eq(1)
      expect(json_body['meta']).to eq('page' => 2, 'per_page' => 2, 'total' => 3)
    end

    it 'rejects a request with no token' do
      get '/api/v1/precon_decks', headers: { 'Accept' => 'application/json' }

      expect_api_error(:unauthorized, 'unauthorized')
    end
  end

  describe 'GET /api/v1/precon_decks/:id' do
    let(:deck) { create(:precon_deck, deck_type: 'Commander Deck') }

    def with_commander
      add_card(deck, commander_card('Heroes', identity: %w[U G]), board_type: 'commander')
    end

    def cards
      json_body['cards']
    end

    def entry(name)
      cards.find { |c| c['card']['name'] == name }
    end

    it 'returns a 100-card Commander precon with the commander on its board, the tokens apart and no sideboard' do
      add_card(deck, create(:magic_card, name: 'Island'), quantity: 49)
      with_commander
      add_card(deck, create(:magic_card, name: 'Forest'), quantity: 50)
      add_card(deck, create(:magic_card, name: 'Extra'), board_type: 'sideBoard', quantity: 15)
      add_card(deck, create(:magic_card, name: 'Turtle', is_token: true), board_type: 'tokens', quantity: 2)

      get "/api/v1/precon_decks/#{deck.id}", headers: api_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['deck']).to include('id' => deck.id, 'card_count' => 100, 'color_identity' => %w[U G])
      expect(cards.map { |c| [c['board'], c['card']['name'], c['quantity']] }).to eq(
        [['commander', 'Heroes', 1], ['mainboard', 'Island', 49], ['mainboard', 'Forest', 50]]
      )
      expect(cards.sum { |c| c['quantity'] }).to eq(100)
      expect(json_body['tokens'].pluck('name')).to eq(['Turtle'])
      expect(json_body['tokens'].first).to include('is_token' => true, 'faces' => a_kind_of(Array))
    end

    it 'is a 404 for a precon that is not a Commander deck' do
      brawl = precon(deck_type: 'Brawl Deck')

      get "/api/v1/precon_decks/#{brawl.id}", headers: api_headers

      expect_api_error(:not_found, 'not_found')
    end

    it 'is a 404 for a Commander precon with no commander' do
      add_card(deck)

      get "/api/v1/precon_decks/#{deck.id}", headers: api_headers

      expect_api_error(:not_found, 'not_found')
    end

    it 'has no tokens for a precon without any' do
      with_commander

      get "/api/v1/precon_decks/#{deck.id}", headers: api_headers

      expect(json_body['tokens']).to eq([])
    end

    it 'adds rulings with include=rulings' do
      with_commander

      get "/api/v1/precon_decks/#{deck.id}", params: { include: 'rulings' }, headers: api_headers

      expect(cards.first['card']['rulings']).to eq([])
    end

    it 'answers 304 to a matching ETag and 200 once the precon changes' do
      with_commander

      get "/api/v1/precon_decks/#{deck.id}", headers: api_headers
      etag = response.headers['ETag']
      expect(etag).to be_present

      get "/api/v1/precon_decks/#{deck.id}", headers: api_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:not_modified)

      add_card(deck)
      get "/api/v1/precon_decks/#{deck.id}", headers: api_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:ok)
    end

    it 'is a 404 for a precon that does not exist' do
      get '/api/v1/precon_decks/0', headers: api_headers

      expect_api_error(:not_found, 'not_found')
    end

    it 'rejects a request with no token' do
      get "/api/v1/precon_decks/#{deck.id}", headers: { 'Accept' => 'application/json' }

      expect_api_error(:unauthorized, 'unauthorized')
    end
  end
end
