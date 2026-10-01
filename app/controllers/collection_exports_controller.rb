# CSV downloads in the shape the collection importer reads back, so a user can export, start over and re-import
class CollectionExportsController < ApplicationController
  before_action :authenticate_user!

  # every card the user owns, across collections and decks
  def index
    csv = CollectionExporter::Csv.call(collections: current_user.collections, list_collections: true)

    send_csv(csv, "#{current_user.username}-all-cards")
  end

  def show
    collection = current_user.collections.find(params[:id])
    csv = CollectionExporter::Csv.call(collections: collection)

    send_csv(csv, collection.name.parameterize.presence || "collection-#{collection.id}")
  end

  private

  def send_csv(csv, basename)
    send_data csv, type: 'text/csv', filename: "#{basename}-#{Date.current.iso8601}.csv"
  end
end
