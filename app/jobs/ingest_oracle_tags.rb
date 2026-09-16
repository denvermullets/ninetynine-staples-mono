# Daily import of Scryfall's Oracle Tags bulk file, then a re-profile of the cards whose tags changed.
#
# Scryfall regenerates the file roughly once a day; ScryfallBulkImport remembers the updated_at it last
# imported so an unchanged file costs one small request. force: true (the dashboard button) skips that check.
class IngestOracleTags < ApplicationJob
  BULK_TYPE = 'oracle_tags'.freeze

  # Past this many cards the oracle id list is a megabyte of job arguments, and re-profiling everything is
  # what BatchProfiler does unscoped anyway.
  PROFILE_ALL_THRESHOLD = 5_000

  queue_as :ingest

  def perform(force: false)
    meta = Scryfall::BulkData.call(type: BULK_TYPE)
    return log("skipped: #{meta[:error]}") if meta[:error]

    record = ScryfallBulkImport.find_or_initialize_by(bulk_type: BULK_TYPE)
    return log('skipped: file unchanged since last import') if !force && unchanged?(record, meta)

    result = Scryfall::OracleTagsImporter.call(records: Scryfall::BulkData.each_record(meta[:download_uri]))
    record.update!(remote_updated_at: meta[:updated_at], imported_at: Time.current,
                   tag_count: result[:tag_count], tagging_count: result[:tagging_count])
    enqueue_profiling(result[:changed_oracle_ids])
  end

  private

  def log(message) = Rails.logger.info("[IngestOracleTags] #{message}")

  def unchanged?(record, meta)
    record.remote_updated_at.present? && record.remote_updated_at.to_i == meta[:updated_at].to_i
  end

  def enqueue_profiling(oracle_ids)
    return if oracle_ids.empty?

    if oracle_ids.size > PROFILE_ALL_THRESHOLD
      ProfileCardRolesJob.perform_later
    else
      ProfileCardRolesJob.perform_later(oracle_ids: oracle_ids)
    end
  end
end
