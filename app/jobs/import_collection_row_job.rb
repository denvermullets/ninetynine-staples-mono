class ImportCollectionRowJob < ApplicationJob
  queue_as :collection_updates

  def perform(collection_id, row_data, skip_existing: false)
    collection = Collection.find(collection_id)

    CollectionImporter::Archidekt.call(
      row_data: row_data,
      collection: collection,
      skip_existing: skip_existing
    )
  end
end
