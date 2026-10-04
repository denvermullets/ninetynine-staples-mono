require 'rails_helper'
require 'support/api/v1_helpers'

RSpec.describe 'API v1 decks', type: :request do
  include_context 'api v1 authenticated request'

  def color(name)
    Color.find_by(name: name) || create(:color, name: name)
  end

  def commander_card(name, identity:, art_crop: "https://cards.scryfall.io/art_crop/#{name}.jpg")
    create(:magic_card, name: name, card_uuid: SecureRandom.uuid, scryfall_oracle_id: SecureRandom.uuid,
                        art_crop: art_crop, image_medium: "https://cards.scryfall.io/normal/#{name}.jpg",
                        color_identities: identity.map { |c| color(c) })
  end

  def add_card(deck, card = create(:magic_card), **attrs)
    create(:collection_magic_card, collection: deck, magic_card: card, **attrs)
  end

  # a staged row pulled from another collection: a move the deck builder hasn't finalized yet
  def add_pending_move(deck, card = create(:magic_card), **attrs)
    source = create(:collection, user: deck.user, collection_type: 'binder')
    add_card(deck, card, quantity: 0, staged: true, source_collection: source, **attrs)
  end

  let(:data) { json_body['data'] }

  describe 'GET /api/v1/decks' do
    it "returns only the signed-in user's decks" do
      own = create(:collection, user: api_user, name: 'Mine', collection_type: 'commander_deck')
      create(:collection, user: create(:user), name: 'Theirs', collection_type: 'commander_deck')

      get '/api/v1/decks', headers: api_headers

      expect(response).to have_http_status(:ok)
      expect(data.pluck('id')).to eq([own.id])
    end

    it 'leaves out collections that are not decks' do
      deck = create(:collection, user: api_user, collection_type: 'deck')
      modern = create(:collection, user: api_user, collection_type: 'modern_deck')
      create(:collection, user: api_user, collection_type: 'binder')

      get '/api/v1/decks', headers: api_headers

      expect(data.pluck('id')).to contain_exactly(deck.id, modern.id)
    end

    it 'narrows to commander decks with type=commander' do
      commander = create(:collection, user: api_user, collection_type: 'commander_deck')
      create(:collection, user: api_user, collection_type: 'deck')

      get '/api/v1/decks', params: { type: 'commander' }, headers: api_headers

      expect(data.pluck('id')).to eq([commander.id])
    end

    it 'includes private decks, newest change first' do
      older = create(:collection, user: api_user, collection_type: 'deck', updated_at: 2.days.ago)
      hidden = create(:collection, user: api_user, collection_type: 'deck', is_public: false, updated_at: 1.day.ago)

      get '/api/v1/decks', headers: api_headers

      expect(data.pluck('id')).to eq([hidden.id, older.id])
      expect(data.first['is_public']).to be(false)
    end

    it 'returns the deck summary with its commanders' do
      atraxa = commander_card('Atraxa', identity: %w[G W U B])
      deck = create(:collection, user: api_user, name: 'Atraxa Superfriends', collection_type: 'commander_deck',
                                 bracket_level: 3)
      add_card(deck, atraxa, board_type: 'commander')

      get '/api/v1/decks', headers: api_headers

      expect(data.first).to include(
        'id' => deck.id, 'name' => 'Atraxa Superfriends', 'collection_type' => 'commander_deck',
        'is_public' => true, 'bracket_level' => 3, 'color_identity' => %w[W U B G],
        'cover_image' => 'https://cards.scryfall.io/art_crop/Atraxa.jpg',
        'updated_at' => deck.reload.updated_at.as_json
      )
      expect(data.first['commanders']).to eq([{
                                               'card_uuid' => atraxa.card_uuid,
                                               'oracle_id' => atraxa.scryfall_oracle_id,
                                               'name' => 'Atraxa',
                                               'image_art_crop' => 'https://cards.scryfall.io/art_crop/Atraxa.jpg',
                                               'image_normal' => 'https://cards.scryfall.io/normal/Atraxa.jpg'
                                             }])
    end

    it 'unions the identity of partner commanders' do
      deck = create(:collection, user: api_user, collection_type: 'commander_deck')
      add_card(deck, commander_card('Thrasios', identity: %w[G U]), board_type: 'commander')
      add_card(deck, commander_card('Tymna', identity: %w[W B]), board_type: 'commander')

      get '/api/v1/decks', headers: api_headers

      expect(data.first['commanders'].pluck('name')).to eq(%w[Thrasios Tymna])
      expect(data.first['color_identity']).to eq(%w[W U B G])
    end

    it 'prefers the cover card over the commander for the cover image' do
      cover = create(:magic_card, art_crop: 'https://cards.scryfall.io/art_crop/cover.jpg')
      deck = create(:collection, user: api_user, collection_type: 'commander_deck', cover_card: cover)
      add_card(deck, commander_card('Atraxa', identity: %w[W]), board_type: 'commander')

      get '/api/v1/decks', headers: api_headers

      expect(data.first['cover_image']).to eq('https://cards.scryfall.io/art_crop/cover.jpg')
    end

    it 'has no commanders, identity or cover for a deck without them' do
      create(:collection, user: api_user, collection_type: 'deck')

      get '/api/v1/decks', headers: api_headers

      expect(data.first).to include('commanders' => [], 'color_identity' => [], 'cover_image' => nil,
                                    'card_count' => 0)
    end

    it 'counts every finish and proxy, and includes needed and staged cards' do
      deck = create(:collection, user: api_user, collection_type: 'commander_deck')
      add_card(deck, quantity: 1, foil_quantity: 1, proxy_quantity: 1, proxy_foil_quantity: 1)
      add_card(deck, quantity: 0, proxy_quantity: 2, board_type: 'sideboard')
      add_card(deck, quantity: 1, needed: true)
      add_card(deck, quantity: 0, staged: true, staged_quantity: 2, staged_foil_quantity: 1)
      add_pending_move(deck, staged_quantity: 5)

      get '/api/v1/decks', headers: api_headers

      expect(data.first['card_count']).to eq(15)
    end

    it 'lists a staged commander' do
      deck = create(:collection, user: api_user, collection_type: 'commander_deck')
      add_pending_move(deck, commander_card('Staged', identity: %w[R]), board_type: 'commander', staged_quantity: 1)

      get '/api/v1/decks', headers: api_headers

      expect(data.first['commanders'].pluck('name')).to eq(['Staged'])
      expect(data.first['color_identity']).to eq(%w[R])
    end

    it 'paginates' do
      create_list(:collection, 3, user: api_user, collection_type: 'deck')

      get '/api/v1/decks', params: { per_page: 2, page: 2 }, headers: api_headers

      expect(data.size).to eq(1)
      expect(json_body['meta']).to eq('page' => 2, 'per_page' => 2, 'total' => 3)
    end

    it 'rejects a request with no token' do
      get '/api/v1/decks', headers: { 'Accept' => 'application/json' }

      expect_api_error(:unauthorized, 'unauthorized')
    end
  end

  describe 'GET /api/v1/decks/:id' do
    let(:deck) { create(:collection, user: api_user, collection_type: 'commander_deck', is_public: false) }

    def cards
      json_body['cards']
    end

    def entry(name)
      cards.find { |c| c['card']['name'] == name }
    end

    def query_count
      count = 0
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION])
      end
      yield
      count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    it 'returns your own private deck with its summary and cards' do
      atraxa = commander_card('Atraxa', identity: %w[W U B G])
      add_card(deck, atraxa, board_type: 'commander')
      add_card(deck, create(:magic_card, name: 'Sol Ring'), quantity: 1)

      get "/api/v1/decks/#{deck.id}", headers: api_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['deck']).to include('id' => deck.id, 'is_public' => false, 'card_count' => 2,
                                           'color_identity' => %w[W U B G])
      expect(cards.first).to include('board' => 'commander', 'quantity' => 1)
      expect(cards.first['card']).to include('card_uuid' => atraxa.card_uuid, 'name' => 'Atraxa')
      expect(entry('Sol Ring')).to include('board' => 'mainboard', 'quantity' => 1)
      expect(json_body['tokens']).to eq([])
    end

    it "returns someone else's public deck" do
      theirs = create(:collection, user: create(:user), collection_type: 'deck', is_public: true)
      add_card(theirs, create(:magic_card, name: 'Sol Ring'))

      get "/api/v1/decks/#{theirs.id}", headers: api_headers

      expect(response).to have_http_status(:ok)
      expect(cards.pluck('quantity')).to eq([1])
    end

    it "is a 404 for someone else's private deck" do
      theirs = create(:collection, user: create(:user), collection_type: 'deck', is_public: false)

      get "/api/v1/decks/#{theirs.id}", headers: api_headers

      expect_api_error(:not_found, 'not_found')
    end

    it 'is a 404 for a collection that is not a deck' do
      binder = create(:collection, user: api_user, collection_type: 'binder')

      get "/api/v1/decks/#{binder.id}", headers: api_headers

      expect_api_error(:not_found, 'not_found')
    end

    it 'adds up every finish and proxy and merges rows of one card on one board' do
      card = create(:magic_card, name: 'Forest')
      add_card(deck, card, quantity: 3, foil_quantity: 2, proxy_quantity: 1, proxy_foil_quantity: 1)
      add_card(deck, card, quantity: 0, staged: true, staged_quantity: 2)
      add_card(deck, card, quantity: 1, board_type: 'sideboard')

      get "/api/v1/decks/#{deck.id}", headers: api_headers

      expect(cards.map { |c| [c['board'], c['quantity']] }).to eq([['mainboard', 9], ['sideboard', 1]])
      expect(json_body['deck']['card_count']).to eq(10)
    end

    it 'includes needed, planned and pending-move cards by their staged counts' do
      add_card(deck, create(:magic_card, name: 'Needed'), quantity: 1, needed: true)
      add_card(deck, create(:magic_card, name: 'Planned'), quantity: 0, staged: true, staged_proxy_quantity: 2)
      add_pending_move(deck, create(:magic_card, name: 'Moving'), staged_quantity: 1, staged_foil_quantity: 1)

      get "/api/v1/decks/#{deck.id}", headers: api_headers

      expect(entry('Needed')['quantity']).to eq(1)
      expect(entry('Planned')['quantity']).to eq(2)
      expect(entry('Moving')['quantity']).to eq(2)
      expect(json_body['deck']['card_count']).to eq(5)
    end

    it 'leaves out rows with no copies' do
      add_card(deck, create(:magic_card, name: 'Empty'), quantity: 0)

      get "/api/v1/decks/#{deck.id}", headers: api_headers

      expect(cards).to eq([])
    end

    it 'adds rulings with include=rulings' do
      card = create(:magic_card, name: 'Sol Ring')
      add_card(deck, card)

      get "/api/v1/decks/#{deck.id}", params: { include: 'rulings' }, headers: api_headers

      expect(cards.first['card']['rulings']).to eq([])
    end

    it 'answers 304 to a matching ETag and 200 once the deck changes' do
      row = add_card(deck, create(:magic_card, name: 'Sol Ring'))

      get "/api/v1/decks/#{deck.id}", headers: api_headers
      etag = response.headers['ETag']
      expect(etag).to be_present
      expect(response.headers['Last-Modified']).to be_present

      get "/api/v1/decks/#{deck.id}", headers: api_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:not_modified)

      row.update!(quantity: 2)
      get "/api/v1/decks/#{deck.id}", headers: api_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:ok)
    end

    it 'changes the ETag when a row is removed' do
      add_card(deck, create(:magic_card, name: 'Sol Ring'))
      gone = add_card(deck, create(:magic_card, name: 'Gone'), updated_at: 1.day.ago)

      get "/api/v1/decks/#{deck.id}", headers: api_headers
      etag = response.headers['ETag']
      gone.delete

      get "/api/v1/decks/#{deck.id}", headers: api_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:ok)
    end

    it 'keeps the query count flat as the deck grows' do
      add_card(deck, commander_card('Atraxa', identity: %w[W]), board_type: 'commander')
      add_card(deck)
      # the first use of a token writes to it, so it doesn't count
      get "/api/v1/decks/#{deck.id}", headers: api_headers
      small = query_count { get "/api/v1/decks/#{deck.id}", headers: api_headers }

      create_list(:magic_card, 8).each { |card| add_card(deck, card) }
      large = query_count { get "/api/v1/decks/#{deck.id}", headers: api_headers }

      expect(large).to eq(small)
    end

    it 'rejects a request with no token' do
      get "/api/v1/decks/#{deck.id}", headers: { 'Accept' => 'application/json' }

      expect_api_error(:unauthorized, 'unauthorized')
    end
  end
end
