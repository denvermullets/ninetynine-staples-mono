require 'rails_helper'
require 'support/api/v1_helpers'

RSpec.describe 'API v1 rooms', type: :request do
  include_context 'api v1 authenticated request'

  def headers_for(user)
    { 'Accept' => 'application/json', 'Authorization' => "Bearer #{ApiToken.issue!(user, name: 'Spec').last}" }
  end

  def join(code, as:)
    post '/api/v1/rooms/join', params: { code: code }, headers: headers_for(as)
  end

  let(:room) { Room.open_for!(api_user) }
  let(:guest) { create(:user) }

  describe 'POST /api/v1/rooms' do
    it 'opens a Room with the caller as Host and returns its Join code' do
      post '/api/v1/rooms', headers: api_headers

      expect(response).to have_http_status(:created)
      expect(json_body).to include('status' => 'open', 'host' => true, 'host_id' => api_user.id)
      expect(json_body['join_code']).to match(/\A[#{Room::CODE_ALPHABET.join}]{6}\z/o)
      expect(json_body['members']).to eq([{ 'id' => api_user.id, 'username' => api_user.username }])
    end

    it 'requires a token' do
      post '/api/v1/rooms', headers: { 'Accept' => 'application/json' }

      expect_api_error(:unauthorized, 'unauthorized')
    end

    it 'never issues a code another live Room holds' do
      codes = Array.new(30) { Room.open_for!(create(:user)).join_code }

      expect(codes.uniq.size).to eq(30)
    end

    it 'uses no lookalike characters' do
      expect(Room::CODE_ALPHABET).not_to include('0', 'O', '1', 'I', 'L', '5', 'S')
    end
  end

  describe 'POST /api/v1/rooms/join' do
    it 'adds the caller to the Room' do
      join(room.join_code, as: guest)

      expect(response).to have_http_status(:ok)
      expect(json_body).to include('id' => room.id, 'host' => false)
      expect(json_body['members'].pluck('id')).to eq([api_user.id, guest.id])
      expect(room.member?(guest)).to be(true)
    end

    it 'ignores case and surrounding spaces in the code' do
      join("  #{room.join_code.downcase} ", as: guest)

      expect(response).to have_http_status(:ok)
    end

    it 'rejects a wrong code' do
      join('ZZZZZZ', as: guest)

      expect_api_error(:not_found, 'no_such_room')
    end

    it 'rejects a started Room' do
      room.start!
      join(room.join_code, as: guest)

      expect_api_error(:conflict, 'room_started')
      expect(room.member?(guest)).to be(false)
    end

    it 'rejects a full Room' do
      (Room::MAX_MEMBERS - 1).times { room.room_memberships.create!(user: create(:user)) }
      join(room.join_code, as: guest)

      expect_api_error(:conflict, 'room_full')
    end

    it 'admits the last seat of the cap' do
      (Room::MAX_MEMBERS - 2).times { room.room_memberships.create!(user: create(:user)) }
      join(room.join_code, as: guest)

      expect(response).to have_http_status(:ok)
    end

    it 'rejects someone already in the Room, the Host included' do
      join(room.join_code, as: api_user)
      expect_api_error(:conflict, 'already_member')

      join(room.join_code, as: guest)
      join(room.join_code, as: guest)
      expect_api_error(:conflict, 'already_member')
    end

    it 'does not work after the Room closes, even once the code is reissued' do
      code = room.join_code
      room.close!
      join(code, as: guest)

      expect_api_error(:not_found, 'no_such_room')

      newer = Room.create!(host: create(:user), join_code: code)
      join(code, as: guest)
      expect(json_body['id']).to eq(newer.id)
    end

    it 'requires the code parameter' do
      post '/api/v1/rooms/join', headers: api_headers

      expect_api_error(:unprocessable_content, 'parameter_missing')
    end

    it 'requires a token' do
      post '/api/v1/rooms/join', params: { code: room.join_code }, headers: { 'Accept' => 'application/json' }

      expect_api_error(:unauthorized, 'unauthorized')
    end
  end

  describe 'POST /api/v1/rooms/:id/start' do
    it 'lets the Host stop admissions' do
      post "/api/v1/rooms/#{room.id}/start", headers: api_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['status']).to eq('started')
      expect(room.reload.started_at).to be_present
    end

    it 'is a no-op when already started' do
      room.start!
      post "/api/v1/rooms/#{room.id}/start", headers: api_headers

      expect(json_body['status']).to eq('started')
    end

    it 'refuses a closed Room' do
      room.close!
      post "/api/v1/rooms/#{room.id}/start", headers: api_headers

      expect_api_error(:conflict, 'room_closed')
    end

    it 'refuses a member who is not the Host' do
      room.room_memberships.create!(user: guest)
      post "/api/v1/rooms/#{room.id}/start", headers: headers_for(guest)

      expect_api_error(:forbidden, 'not_host')
      expect(room.reload).to be_open
    end

    it 'hides the Room from someone outside it' do
      post "/api/v1/rooms/#{room.id}/start", headers: headers_for(guest)

      expect_api_error(:not_found, 'not_found')
    end
  end

  describe 'POST /api/v1/rooms/:id/close' do
    it 'lets the Host close the Room' do
      post "/api/v1/rooms/#{room.id}/close", headers: api_headers

      expect(json_body['status']).to eq('closed')
      expect(room.reload.closed_at).to be_present
    end

    it 'refuses a member who is not the Host' do
      room.room_memberships.create!(user: guest)
      post "/api/v1/rooms/#{room.id}/close", headers: headers_for(guest)

      expect_api_error(:forbidden, 'not_host')
    end
  end
end
