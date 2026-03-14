class CollectionImportsController < ApplicationController
  before_action :authenticate_user!

  def new
    @collections = current_user.collections.order(:name)
  end

  def create
    validate_csv_file!

    collection = resolve_collection!
    result = parse_and_import(collection)

    redirect_to collection_show_path(current_user.username, collection.id),
                notice: "Import started! #{result[:rows_queued]} cards queued for processing."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to new_collection_import_path, alert: e.message
  end

  private

  def validate_csv_file!
    raise ArgumentError, 'Please select a CSV file to import.' if params[:csv_file].blank?
  end

  def parse_and_import(collection)
    CollectionImporter::CsvParser.call(
      csv_data: params[:csv_file].read,
      collection: collection,
      user: current_user,
      skip_existing: params[:skip_existing] == '1'
    )
  end

  def resolve_collection!
    collection = if params[:new_collection_name].present?
                   current_user.collections.create!(
                     name: params[:new_collection_name],
                     description: 'Imported collection',
                     collection_type: 'collection'
                   )
                 elsif params[:collection_id].present?
                   current_user.collections.find_by(id: params[:collection_id])
                 end

    raise ArgumentError, 'Please select or create a collection.' if collection.nil?

    collection
  end
end
