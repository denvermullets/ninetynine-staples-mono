class SettingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @collections = current_user.ordered_collections
    @api_tokens = active_api_tokens
  end

  def move_collection
    collection_id = params[:collection_id]
    direction = params[:direction]

    if current_user.move_collection(collection_id, direction)
      render_collection_list
    else
      head :unprocessable_entity
    end
  end

  def reorder_collections
    if current_user.reorder_collections(params[:collection_ids])
      render_collection_list
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
    update_visibility(:game_tracker_public)
  end

  def update_trades_visibility
    update_visibility(:trades_public)
  end

  def update_wants_visibility
    update_visibility(:wants_public)
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

  def revoke_api_token
    current_user.api_tokens.active.find(params[:id]).revoke!
    render_api_token_list
  end

  def revoke_all_api_tokens
    current_user.api_tokens.revoke_all!
    render_api_token_list
  end

  private

  def active_api_tokens
    current_user.api_tokens.active.order(created_at: :desc)
  end

  def render_api_token_list
    @api_tokens = active_api_tokens
    respond_to do |format|
      format.turbo_stream { render :revoke_api_token }
      format.html { redirect_to settings_path(anchor: 'game-sessions'), status: :see_other }
    end
  end

  def render_collection_list
    @collections = current_user.ordered_collections
    respond_to do |format|
      format.turbo_stream { render :move_collection }
      format.html { redirect_to settings_path }
    end
  end

  def update_visibility(attribute)
    is_public = [true, 'true'].include?(params[:public])
    current_user.update(attribute => is_public) ? head(:ok) : head(:unprocessable_entity)
  end

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
    User::COLUMN_KEYS.to_h do |key|
      [key, ['true', true].include?(columns[key])]
    end
  end
end
