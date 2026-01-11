class SettingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @collections = current_user.ordered_collections
  end

  def move_collection
    collection_id = params[:collection_id]
    direction = params[:direction]

    if current_user.move_collection(collection_id, direction)
      @collections = current_user.ordered_collections
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to settings_path }
      end
    else
      head :unprocessable_entity
    end
  end

  def update_column_visibility
    columns = params[:visible_columns] || {}

    # Ensure at least one column remains visible
    visible_count = User::COLUMN_KEYS.count { |key| ['true', true].include?(columns[key]) }

    if visible_count < 1
      render json: { error: 'At least one column must remain visible' }, status: :unprocessable_entity
      return
    end

    column_prefs = User::COLUMN_KEYS.each_with_object({}) do |key, hash|
      hash[key] = ['true', true].include?(columns[key])
    end

    current_user.visible_columns = column_prefs

    if current_user.save
      head :ok
    else
      head :unprocessable_entity
    end
  end
end
