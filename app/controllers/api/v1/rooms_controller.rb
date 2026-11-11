# Network game Rooms: the Host creates one and shares its Join code, others join with it. 99staples checks
# the code, that the Room is still open and that it has space; the Host marks it started (no more
# admissions) and closed (the code is dead). Membership is what later gates the Relay.
class Api::V1::RoomsController < Api::V1::BaseController
  before_action :set_hosted_room, only: %i[start close]

  # 201 with the Room and its Join code
  def create
    room = Room.open_for!(current_api_user)
    render json: Api::V1::RoomSerializer.one(room, viewer: current_api_user), status: :created
  end

  # POST /rooms/join { code }. Each way it can fail has its own code: no_such_room (wrong code, or the
  # Room closed), room_started, room_full, already_member
  def join
    room = Room.find_live_by_code(params.require(:code))
    return render_error(:not_found, 'no_such_room', 'No open Room has that Join code') unless room

    room.with_lock do
      error = join_error(room)
      return render_error(*error) if error

      room.room_memberships.create!(user: current_api_user)
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

  private

  def join_error(room)
    if room.member?(current_api_user)
      [:conflict, 'already_member', 'You are already in this Room']
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
