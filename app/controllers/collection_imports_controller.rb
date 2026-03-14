class CollectionImportsController < ApplicationController
  before_action :authenticate_user!

  def new
    @collections = current_user.collections
                               .where(collection_type: 'collection')
                               .order(:name)
  end

  def create
    csv_file = params[:csv_file]

    if csv_file.blank?
      redirect_to new_collection_import_path, alert: 'Please select a CSV file to import.'
      return
    end

    collection = resolve_collection
    if collection.nil?
      redirect_to new_collection_import_path, alert: 'Please select or create a collection.'
      return
    end

    csv_data = csv_file.read
    result = CollectionImporter::CsvParser.call(
      csv_data: csv_data,
      collection: collection,
      user: current_user
    )

    redirect_to collection_show_path(current_user.username, collection.id),
                notice: "Import started! #{result[:rows_queued]} cards queued for processing."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to new_collection_import_path, alert: e.message
  end

  private

  def resolve_collection
    if params[:new_collection_name].present?
      current_user.collections.create!(
        name: params[:new_collection_name],
        description: 'Imported collection',
        collection_type: 'collection'
      )
    elsif params[:collection_id].present?
      current_user.collections.find_by(id: params[:collection_id])
    end
  end
end
