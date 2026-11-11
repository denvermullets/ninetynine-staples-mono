require 'rails_helper'
require 'support/api/v1_helpers'

RSpec.describe 'API v1 game records', type: :request do
  include_context 'api v1 authenticated request'

  let(:guest) { create(:user) }
  let(:room) { Room.open_for!(api_user).tap { |r| r.room_memberships.create!(user: guest) }.tap(&:start!) }
  let(:record) { { 'seed' => 42, 'commands' => Array.new(200) { |i| { 'type' => 'pass', 'n' => i } } }.to_json }
  let(:seats) { [{ seat: 0, user_id: api_user.id }, { seat: 1, user_id: guest.id }, { seat: 2, user_id: nil }] }
  let(:params) { { end_status: 'finished', seats: seats, record: record } }

  def headers_for(user)
    { 'Accept' => 'application/json', 'Authorization' => "Bearer #{ApiToken.issue!(user, name: 'Spec').last}" }
  end

  def upload(room_id: room.id, headers: api_headers, body: params)
    post "/api/v1/rooms/#{room_id}/game_record", params: body.to_json,
                                                 headers: headers.merge('Content-Type' => 'application/json')
  end

  describe 'POST /api/v1/rooms/:id/game_record' do
    it 'stores the record compressed with its end status and Seat holders' do
      upload

      expect(response).to have_http_status(:created)
      expect(json_body).to include('room_id' => room.id, 'end_status' => 'finished',
                                   'seats' => [{ 'seat' => 0, 'user_id' => api_user.id },
                                               { 'seat' => 1, 'user_id' => guest.id },
                                               { 'seat' => 2, 'user_id' => nil }])
      stored = room.reload.game_record
      expect(stored.data.bytesize).to be < record.bytesize
      expect(ActiveSupport::Gzip.decompress(stored.data)).to eq(record)
      expect(json_body['size']).to eq(stored.data.bytesize)
    end

    it 'accepts an Unfinished record' do
      upload(body: params.merge(end_status: 'unfinished'))

      expect(response).to have_http_status(:created)
      expect(room.game_record.end_status).to eq('unfinished')
    end

    it 'accepts a record for a Room that has already closed' do
      room.close!
      upload

      expect(response).to have_http_status(:created)
    end

    it 'only takes one record per Room' do
      upload
      upload

      expect_api_error(:conflict, 'record_exists')
      expect(GameRecord.where(room: room).count).to eq(1)
    end

    it 'refuses a Participant who is not the Host' do
      upload(headers: headers_for(guest))

      expect_api_error(:forbidden, 'not_host')
      expect(room.reload.game_record).to be_nil
    end

    it 'hides the Room from a user who is not in it' do
      upload(headers: headers_for(create(:user)))

      expect_api_error(:not_found, 'not_found')
    end

    it 'requires a token' do
      upload(headers: { 'Accept' => 'application/json' })

      expect_api_error(:unauthorized, 'unauthorized')
    end

    it 'refuses a Room whose game has not started' do
      open_room = Room.open_for!(api_user)
      upload(room_id: open_room.id)

      expect_api_error(:conflict, 'room_not_started')
    end

    it 'rejects a record over the compressed cap' do
      stub_const('GameRecord::MAX_COMPRESSED_BYTES', 1_000)
      upload(body: params.merge(record: SecureRandom.hex(2_000)))

      expect_api_error(:content_too_large, 'record_too_large')
      expect(room.reload.game_record).to be_nil
    end

    it 'measures the cap after compression' do
      stub_const('GameRecord::MAX_COMPRESSED_BYTES', 1_000)
      upload(body: params.merge(record: 'a' * 50_000))

      expect(response).to have_http_status(:created)
    end

    it 'rejects a Seat holder who is not in the Room' do
      upload(body: params.merge(seats: [{ seat: 0, user_id: create(:user).id }]))

      expect_api_error(:unprocessable_content, 'invalid_parameter')
    end

    it 'rejects a repeated Seat' do
      upload(body: params.merge(seats: [{ seat: 0, user_id: api_user.id }, { seat: 0, user_id: guest.id }]))

      expect_api_error(:unprocessable_content, 'invalid_parameter')
    end

    it 'rejects an unknown end status' do
      upload(body: params.merge(end_status: 'draw'))

      expect_api_error(:unprocessable_content, 'invalid_parameter')
    end

    it 'rejects a missing record, seats or end status' do
      %i[record seats end_status].each do |key|
        upload(body: params.except(key))
        expect_api_error(:unprocessable_content, 'parameter_missing')
      end
    end

    it 'rejects an empty Seat list' do
      upload(body: params.merge(seats: []))

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
  describe 'reading records back' do
    let(:outsider) { create(:user) }

    def stored(host:, holders:, at: Time.current)
      room = Room.open_for!(host)
      holders.pluck('user_id').compact.excluding(host.id).each { |id| room.room_memberships.create!(user_id: id) }
      room.start!
      GameRecord.create!(room: room, end_status: 'finished', data: GameRecord.compress(record), created_at: at,
                         seat_holders: holders)
    end

    def read(path, user: api_user)
      get path, headers: headers_for(user)
    end

    describe 'GET /api/v1/game_records' do
      it 'lists the records the user held a Seat in, newest first, with date, Seats and end status' do
        older = stored(host: api_user, holders: [{ 'seat' => 0, 'user_id' => api_user.id }], at: 2.days.ago)
        newer = stored(host: create(:user), holders: [{ 'seat' => 0, 'user_id' => create(:user).id },
                                                      { 'seat' => 1, 'user_id' => api_user.id }])
        stored(host: create(:user), holders: [{ 'seat' => 0, 'user_id' => nil }])

        read('/api/v1/game_records')

        expect(response).to have_http_status(:ok)
        expect(json_body['data'].pluck('room_id')).to eq([newer.room_id, older.room_id])
        expect(json_body['data'].first).to include('end_status' => 'finished', 'created_at' => be_present)
        expect(json_body['data'].first['seats'].size).to eq(2)
        expect(json_body['data'].first).not_to have_key('record')
        expect(json_body['meta']).to include('total' => 2)
      end

      it 'is empty for someone who held no Seat' do
        stored(host: api_user, holders: [{ 'seat' => 0, 'user_id' => api_user.id }])
        read('/api/v1/game_records', user: outsider)

        expect(json_body['data']).to eq([])
      end

      it 'requires a token' do
        get '/api/v1/game_records', headers: { 'Accept' => 'application/json' }

        expect_api_error(:unauthorized, 'unauthorized')
      end
    end

    describe 'GET /api/v1/game_records/:room_id' do
      it 'returns the decompressed record to a Seat holder' do
        stored = stored(host: create(:user), holders: [{ 'seat' => 0, 'user_id' => api_user.id }])
        read("/api/v1/game_records/#{stored.room_id}")

        expect(response).to have_http_status(:ok)
        expect(json_body).to include('room_id' => stored.room_id, 'record' => record)
      end

      it 'is a 404 for a Room member who held no Seat' do
        host = create(:user)
        stored = stored(host: host, holders: [{ 'seat' => 0, 'user_id' => host.id }, { 'seat' => 1, 'user_id' => nil }])
        stored.room.room_memberships.create!(user: outsider)
        read("/api/v1/game_records/#{stored.room_id}", user: outsider)

        expect_api_error(:not_found, 'not_found')
      end

      it 'is a 404 for a record that does not exist' do
        read('/api/v1/game_records/0')

        expect_api_error(:not_found, 'not_found')
      end
    end
  end
end
