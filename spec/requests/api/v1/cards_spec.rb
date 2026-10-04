require 'rails_helper'
require 'support/api/v1_helpers'

RSpec.describe 'API v1 cards', type: :request do
  include_context 'api v1 authenticated request'

  def set(set_type: 'expansion', release_date: '2024-01-01')
    create(:boxset, set_type: set_type, release_date: release_date)
  end

  def card(name = 'Lightning Bolt', oracle_id: SecureRandom.uuid, boxset: set, **attrs)
    create(:magic_card, name: name, scryfall_oracle_id: oracle_id, card_uuid: SecureRandom.uuid, boxset: boxset,
                        image_medium: "https://cards.scryfall.io/normal/#{SecureRandom.hex(4)}.jpg", **attrs)
  end

  def post_batch(body)
    post '/api/v1/cards/batch', params: body.to_json,
                                headers: api_headers.merge('Content-Type' => 'application/json')
  end

  describe 'POST /api/v1/cards/batch' do
    it 'returns card objects by oracle id in the order asked, reporting unknown ids as missing' do
      bolt = card('Lightning Bolt')
      ring = card('Sol Ring')
      unknown = SecureRandom.uuid

      post_batch(oracle_ids: [ring.scryfall_oracle_id, unknown, bolt.scryfall_oracle_id, 'not-a-uuid'])

      expect(response).to have_http_status(:ok)
      expect(json_body['cards'].pluck('card_uuid')).to eq([ring.card_uuid, bolt.card_uuid])
      expect(json_body['cards'].first).to include('oracle_id' => ring.scryfall_oracle_id, 'name' => 'Sol Ring',
                                                  'faces' => a_kind_of(Array))
      expect(json_body['missing']).to eq([unknown, 'not-a-uuid'])
    end

    it 'picks the newest regular printing with an image for an oracle id' do
      oracle_id = SecureRandom.uuid
      card(oracle_id: oracle_id, boxset: set(release_date: '2020-01-01'))
      newest = card(oracle_id: oracle_id, boxset: set(release_date: '2023-01-01'))
      card(oracle_id: oracle_id, boxset: set(release_date: '2025-01-01'), image_medium: nil)
      card(oracle_id: oracle_id, boxset: set(set_type: 'promo', release_date: '2025-06-01'))
      card(oracle_id: oracle_id, boxset: set(set_type: 'memorabilia', release_date: '2025-06-01'))

      post_batch(oracle_ids: [oracle_id])

      expect(json_body['cards'].pluck('card_uuid')).to eq([newest.card_uuid])
    end

    it 'falls back to a promo printing when that is all there is' do
      promo = card(boxset: set(set_type: 'promo'))

      post_batch(oracle_ids: [promo.scryfall_oracle_id])

      expect(json_body['cards'].pluck('card_uuid')).to eq([promo.card_uuid])
    end

    it 'returns exact printings by card uuid' do
      oracle_id = SecureRandom.uuid
      old = card(oracle_id: oracle_id, boxset: set(release_date: '2010-01-01'))
      card(oracle_id: oracle_id)

      post_batch(card_uuids: [old.card_uuid.upcase, 'nope'])

      expect(json_body['cards'].pluck('card_uuid')).to eq([old.card_uuid])
      expect(json_body['missing']).to eq(['nope'])
    end

    it 'returns one card for a repeated id' do
      bolt = card

      post_batch(oracle_ids: [bolt.scryfall_oracle_id, bolt.scryfall_oracle_id])

      expect(json_body['cards'].size).to eq(1)
    end

    it 'adds rulings with ?include=rulings' do
      bolt = card
      post '/api/v1/cards/batch?include=rulings', params: { oracle_ids: [bolt.scryfall_oracle_id] }.to_json,
                                                  headers: api_headers.merge('Content-Type' => 'application/json')

      expect(json_body['cards'].first['rulings']).to eq([])
    end

    it 'refuses more than 200 ids' do
      post_batch(oracle_ids: Array.new(201) { SecureRandom.uuid })

      expect_api_error(:unprocessable_content, 'too_many_ids')
    end

    it 'refuses oracle_ids and card_uuids together' do
      post_batch(oracle_ids: [SecureRandom.uuid], card_uuids: [SecureRandom.uuid])

      expect_api_error(:unprocessable_content, 'invalid_parameter')
    end

    it 'needs ids' do
      post_batch(oracle_ids: [])

      expect_api_error(:unprocessable_content, 'parameter_missing')
    end

    it 'needs a token' do
      post '/api/v1/cards/batch', params: { oracle_ids: [SecureRandom.uuid] }

      expect_api_error(:unauthorized, 'unauthorized')
    end
  end

  describe 'GET /api/v1/cards/search' do
    let(:data) { json_body['data'] }

    it 'returns one summary per card, the exact name first' do
      oracle_id = SecureRandom.uuid
      card('Lightning Bolt', oracle_id: oracle_id, boxset: set(release_date: '2010-01-01'))
      newest = card('Lightning Bolt', oracle_id: oracle_id, mana_cost: '{R}', card_type: 'Instant')
      helix = card('Lightning Helix')
      chain = card('Chain Lightning')
      card('Shock')

      get '/api/v1/cards/search', params: { q: 'lightning bolt' }, headers: api_headers

      expect(response).to have_http_status(:ok)
      expect(data.pluck('card_uuid')).to eq([newest.card_uuid])
      expect(data.first).to eq(
        'card_uuid' => newest.card_uuid, 'oracle_id' => oracle_id, 'name' => 'Lightning Bolt',
        'set_code' => newest.boxset.code, 'type_line' => 'Instant', 'mana_cost' => '{R}', 'is_token' => false,
        'image_art_crop' => nil, 'image_normal' => newest.image_medium
      )

      get '/api/v1/cards/search', params: { q: 'lightning' }, headers: api_headers

      expect(json_body['data'].pluck('name')).to eq(['Lightning Bolt', 'Lightning Helix', 'Chain Lightning'])
      expect(json_body['data'].pluck('card_uuid')).to include(helix.card_uuid, chain.card_uuid)
      expect(json_body['meta']).to eq('page' => 1, 'per_page' => 25, 'total' => 3)
    end

    it 'leaves tokens out unless token=true' do
      card('Treasure Map')
      token = card('Treasure', is_token: true)

      get '/api/v1/cards/search', params: { q: 'treasure' }, headers: api_headers
      expect(data.pluck('name')).to eq(['Treasure Map'])

      get '/api/v1/cards/search', params: { q: 'treasure', token: 'true' }, headers: api_headers
      expect(json_body['data'].pluck('card_uuid')).to eq([token.card_uuid])
    end

    it 'treats LIKE wildcards in q literally' do
      card

      get '/api/v1/cards/search', params: { q: '%' }, headers: api_headers

      expect(data).to eq([])
    end

    it 'needs q' do
      get '/api/v1/cards/search', headers: api_headers

      expect_api_error(:unprocessable_content, 'parameter_missing')
    end
  end
end
