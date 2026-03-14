class ImportCollectionRowJob < ApplicationJob
  queue_as :collection_updates

  def perform(collection_id, row_data)
    collection = Collection.find(collection_id)

    CollectionImporter::Archidekt.call(
      row_data: row_data,
      collection: collection
    )
  end
end
