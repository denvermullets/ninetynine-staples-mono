# Root of /api/v1. ActionController::API on purpose: no cookie session, no CSRF, no login redirect -
# the Godot client authenticates with a bearer token, and every failure renders the same
# envelope: { "error": { "code": "...", "message": "..." } }
class Api::V1::BaseController < ActionController::API
  include Api::TokenAuthentication

  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  # declared first so the specific handlers below win. Off when requests are local (dev/test) so a
  # bug shows its backtrace instead of a polite 500
  rescue_from StandardError, with: :render_internal_error unless Rails.application.config.consider_all_requests_local
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_unprocessable

  # an unknown path is a 404 whether or not the caller is signed in
  skip_before_action :authenticate_api_user!, only: :route_not_found

  # the catch-all route at the bottom of the api namespace, so a typo'd path gets JSON instead of the
  # HTML 404 page
  def route_not_found
    render_error(:not_found, 'not_found', "No route matches #{request.method} #{request.path}")
  end

  private

  def render_error(status, code, message)
    render json: { error: { code: code, message: message } }, status: status
  end

  def render_not_found(error)
    render_error(:not_found, 'not_found', error.message)
  end

  def render_unprocessable(error)
    render_error(:unprocessable_content, 'parameter_missing', error.message)
  end

  def render_internal_error(error)
    Rails.logger.error("#{error.class}: #{error.message}\n#{Array(error.backtrace).first(20).join("\n")}")
    render_error(:internal_server_error, 'internal_error', 'Something went wrong')
  end

  # page/per_page from params, per_page clamped to MAX_PER_PAGE. Returns the page of records and the
  # meta block that goes beside them: render json: { data: ..., meta: meta }
  def paginate(scope)
    page = [params[:page].to_i, 1].max
    per_page = params[:per_page].to_i
    per_page = DEFAULT_PER_PAGE unless per_page.positive?
    per_page = [per_page, MAX_PER_PAGE].min

    records = scope.offset((page - 1) * per_page).limit(per_page)
    [records, { page: page, per_page: per_page, total: scope.count }]
  end

  # ETag/Last-Modified for a deck and its card rows (collection_magic_cards or precon_deck_cards).
  # Last-Modified is the newest of the deck, its rows and their cards. The ETag keeps each of those to
  # the microsecond (Last-Modified only has whole seconds) plus the row count, since removing a row
  # changes the deck without touching any timestamp that is left
  def deck_cache_validators(deck, rows)
    rows_changed, cards_changed, row_count =
      rows.joins(:magic_card)
          .pick(Arel.sql("MAX(#{rows.table_name}.updated_at)"), Arel.sql('MAX(magic_cards.updated_at)'),
                Arel.sql('COUNT(*)'))
    stamps = [deck.updated_at, rows_changed, cards_changed]

    { etag: [deck.class.name, deck.id, *stamps.map { |t| t&.utc&.iso8601(6) }, row_count, params[:include]],
      last_modified: stamps.compact.max }
  end
end
