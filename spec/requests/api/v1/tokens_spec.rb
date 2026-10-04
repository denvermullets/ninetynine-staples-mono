require 'rails_helper'
require 'support/api/v1_helpers'

RSpec.describe 'API v1 tokens', type: :request do
  include_context 'api v1 authenticated request'

  let(:data) { json_body['data'] }

  def color(name)
    Color.find_by(name: name) || create(:color, name: name)
  end

  def token(name, release_date: '2024-01-01', colors: [], **attrs)
    create(:magic_card, name: name, is_token: true, layout: 'token', card_uuid: SecureRandom.uuid,
                        scryfall_oracle_id: SecureRandom.uuid, colors: colors.map { |c| color(c) },
                        boxset: create(:boxset, set_type: 'token', release_date: release_date),
                        image_medium: "https://cards.scryfall.io/normal/#{SecureRandom.hex(4)}.jpg", **attrs)
  end

  describe 'GET /api/v1/tokens' do
    it 'returns token card objects, one per name, power/toughness, colors and text' do
      treasure_text = '{T}, Sacrifice this token: Add one mana of any color.'
      token('Treasure', text: treasure_text, release_date: '2020-01-01')
      treasure = token('Treasure', text: treasure_text, release_date: '2023-01-01')
      white = token('Soldier', power: '1', toughness: '1', colors: %w[W])
      red = token('Soldier', power: '1', toughness: '1', colors: %w[R])
      big = token('Soldier', power: '2', toughness: '2', colors: %w[W])
      create(:magic_card, name: 'Treasure Map', card_uuid: SecureRandom.uuid)

      get '/api/v1/tokens', headers: api_headers

      expect(response).to have_http_status(:ok)
      expect(data.pluck('card_uuid')).to contain_exactly(treasure.card_uuid, white.card_uuid, red.card_uuid,
                                                         big.card_uuid)
      soldier = data.find { |t| t['card_uuid'] == white.card_uuid }
      expect(soldier['is_token']).to be(true)
      expect(soldier['faces']).to match([a_hash_including('power' => '1', 'colors' => %w[W])])
      expect(json_body['meta']).to include('total' => 4)
    end

    it 'searches by name' do
      treasure = token('Treasure')
      token('Soldier')

      get '/api/v1/tokens', params: { q: 'treas' }, headers: api_headers

      expect(data.pluck('card_uuid')).to eq([treasure.card_uuid])
    end

    it 'lists a double-faced token once, from its front' do
      front = token('Incubator', card_side: 'a')
      token('Phyrexian', card_side: 'b')

      get '/api/v1/tokens', headers: api_headers

      expect(data.pluck('card_uuid')).to eq([front.card_uuid])
    end

    it 'needs a token' do
      get '/api/v1/tokens'

      expect_api_error(:unauthorized, 'unauthorized')
    end
  end
end
