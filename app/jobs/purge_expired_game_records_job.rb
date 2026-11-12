# Deletes GameRecords older than GameRecord::RETENTION; their Seat holders have had that long to download them.
class PurgeExpiredGameRecordsJob < ApplicationJob
  queue_as :background

  def perform
    GameRecord.purge_expired!
  end
end
