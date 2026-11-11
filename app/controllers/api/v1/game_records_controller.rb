# Finished network games for the people who held a Seat in them. Everyone else gets a 404, the same as a
# record that doesn't exist or has been purged.
class Api::V1::GameRecordsController < Api::V1::BaseController
  # the signed-in user's records, newest first, metadata only
  def index
    records, meta = paginate(GameRecord.held_by(current_api_user).order(created_at: :desc, id: :desc))
    render json: { data: records.map { |record| Api::V1::GameRecordSerializer.one(record) }, meta: meta }
  end

  # GET /game_records/:room_id: the metadata plus `record`, the uncompressed record text
  def show
    record = GameRecord.held_by(current_api_user).find_by!(room_id: params[:room_id])
    render json: Api::V1::GameRecordSerializer.one(record).merge(record: record.record_text)
  end
end
