class SyncDeckCombosJob < ApplicationJob
  queue_as :background

  def perform(collection_id)
    Rails.logger.info("[SyncDeckCombosJob] Starting for collection_id=#{collection_id}")

    collection = Collection.find_by(id: collection_id)
    unless collection
      Rails.logger.info('[SyncDeckCombosJob] Collection not found, aborting')
      return
    end

    unless Collection.deck_type?(collection.collection_type)
      Rails.logger.info("[SyncDeckCombosJob] type '#{collection.collection_type}' is not a deck, aborting")
      return
    end

    Rails.logger.info("[SyncDeckCombosJob] Found deck '#{collection.name}'")
    result = CommanderSpellbook::SyncDeckCombos.call(collection: collection)
    Rails.logger.info("[SyncDeckCombosJob] Done. Result: #{result.inspect}")
  end
end
