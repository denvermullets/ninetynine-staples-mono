# Network game Rooms: the Host creates one and shares its Join code, others join with it. 99staples checks
# the code, that the Room is still open and that it has space; the Host marks it started (no more
# admissions) and closed (the code is dead). Membership is what later gates the Relay.
class Api::V1::RoomsController < Api::V1::BaseController
  before_action :set_hosted_room, only: %i[start close upload_game_record remove_member]

  # 201 with the Room and its Join code
  def create
    room = Room.open_for!(current_api_user)
    render json: Api::V1::RoomSerializer.one(room, viewer: current_api_user), status: :created
  end

  # POST /rooms/join { code }. Each way it can fail has its own code: no_such_room (wrong code, or the
  # Room closed), room_started, room_full, already_member. A member of a started Room joining again (their
  # client restarted) gets the Room back as for a normal join
  def join
    room = Room.find_live_by_code(params.require(:code))
    return render_error(:not_found, 'no_such_room', 'No open Room has that Join code') unless room

    room.with_lock do
      rejoin = room.started? && room.member?(current_api_user)
      error = rejoin ? nil : join_error(room)
      return render_error(*error) if error

      room.room_memberships.create!(user: current_api_user) unless rejoin
    end
    render json: Api::V1::RoomSerializer.one(room, viewer: current_api_user)
  end

  # no more admissions. Starting twice is a no-op
  def start
    return render_error(:conflict, 'room_closed', 'The Room is closed') if @room.closed?

    @room.start! if @room.open?
    render json: Api::V1::RoomSerializer.one(@room, viewer: current_api_user)
  end

  def close
    @room.close! unless @room.closed?
    render json: Api::V1::RoomSerializer.one(@room, viewer: current_api_user)
  end

  # DELETE /rooms/:id/members/:user_id. The Host Removes a member: their subscription is dropped and they
  # can't join this Room again. The Host can't Remove themselves
  def remove_member
    return render_error(:conflict, 'room_closed', 'The Room is closed') if @room.closed?

    user = @room.members.find(params[:user_id])
    return render_error(:unprocessable_content, 'cannot_remove_host', 'The Host cannot be removed') if @room.host?(user)

    @room.remove_member!(user)
    render json: Api::V1::RoomSerializer.one(@room, viewer: current_api_user)
  end

  # POST /rooms/:id/game_record { end_status, seats: [{ seat, user_id }], record }. The Host uploads the
  # finished GameRecord once; `record` is its text, compressed here, and the compressed size is capped.
  # A Seat nobody held has a null user_id
  def upload_game_record
    return render_error(:conflict, 'room_not_started', 'The game in this Room has not started') if @room.open?

    attrs = game_record_params
    return render_error(:unprocessable_content, 'invalid_parameter', 'seats is malformed') unless attrs

    # GameRecord.new, not build_game_record: building through the has_one would destroy an existing record
    record = GameRecord.new(room: @room, end_status: attrs[:end_status], seat_holders: attrs[:seats],
                            data: GameRecord.compress(attrs[:record]))
    return render_error(:content_too_large, 'record_too_large', 'The GameRecord is over 2 MB') if record.too_large?

    save_game_record(record)
  end

  private

  def save_game_record(record)
    @room.with_lock do
      if GameRecord.exists?(room_id: @room.id)
        return render_error(:conflict, 'record_exists', 'This Room already has a GameRecord')
      end

      if record.save
        render json: Api::V1::GameRecordSerializer.one(record), status: :created
      else
        render_error(:unprocessable_content, 'invalid_parameter', record.errors.full_messages.to_sentence)
      end
    end
  end

  def game_record_params
    record = params.require(:record)
    seats = params.require(:seats)
    raise ActionController::ParameterMissing, :seats if seats.blank?

    end_status = params.require(:end_status).to_s
    holders = seat_holders(seats)
    { record: record.to_s, end_status: end_status, seats: holders } if holders
  end

  # [{ 'seat' => Integer, 'user_id' => Integer or nil }], or nil when seats isn't that shape
  def seat_holders(seats)
    return unless seats.is_a?(Array) && seats.all?(ActionController::Parameters)

    holders = seats.map { |entry| entry.permit(:seat, :user_id).to_h.slice('seat', 'user_id') }
    holders if holders.all? { |holder| well_formed_holder?(holder) }
  end

  def well_formed_holder?(holder)
    holder['seat'].is_a?(Integer) && [NilClass, Integer].any? { |type| holder['user_id'].is_a?(type) }
  end

  def join_error(room)
    if room.member?(current_api_user)
      [:conflict, 'already_member', 'You are already in this Room']
    elsif room.removed?(current_api_user)
      [:forbidden, 'removed', 'The Host removed you from this Room']
    elsif room.started?
      [:conflict, 'room_started', 'The game in this Room has already started']
    elsif room.full?
      [:conflict, 'room_full', 'This Room is full']
    end
  end

  # a Room you aren't in is a 404, whether it exists or not; a member who isn't the Host gets 403
  def set_hosted_room
    @room = Room.find(params[:id])
    return if @room.host?(current_api_user)
    raise ActiveRecord::RecordNotFound unless @room.member?(current_api_user)

    render_error(:forbidden, 'not_host', 'Only the Host can do that')
  end
end
