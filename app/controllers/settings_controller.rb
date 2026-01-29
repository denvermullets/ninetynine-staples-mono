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
    view = params[:view]&.to_s
    return render_invalid_view unless valid_view?(view)

    column_prefs = build_column_prefs
    return render_minimum_columns_error if column_prefs.values.count(true) < 1

    current_user.set_visible_columns(column_prefs, view: view)
    current_user.save ? head(:ok) : head(:unprocessable_entity)
  end

  def update_game_tracker_visibility
    is_public = [true, 'true'].include?(params[:public])
    if current_user.update(game_tracker_public: is_public)
      head :ok
    else
      head :unprocessable_entity
    end
  end

  def update_theme
    theme = params[:theme]
    return head :unprocessable_entity unless %w[dark light].include?(theme)

    current_user.theme = theme
    if current_user.save
      head :ok
    else
      head :unprocessable_entity
    end
  end

  private

  def valid_view?(view)
    %w[collections boxsets].include?(view)
  end

  def render_invalid_view
    render json: { error: 'Invalid view parameter' }, status: :unprocessable_entity
  end

  def render_minimum_columns_error
    render json: { error: 'At least one column must remain visible' }, status: :unprocessable_entity
  end

  def build_column_prefs
    columns = params[:visible_columns] || {}
    User::COLUMN_KEYS.each_with_object({}) do |key, hash|
      hash[key] = ['true', true].include?(columns[key])
    end
  end
end
