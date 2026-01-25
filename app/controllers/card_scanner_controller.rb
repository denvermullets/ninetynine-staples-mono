class CardScannerController < ApplicationController
  include CardScannerSerialization

  before_action :authenticate_user!
  before_action :load_collections, only: [:show]

  def show
    return unless @collections.empty?

    flash.now[:alert] = 'You need to create a collection first before scanning cards.'
  end

  def search
    @results = CardScanner::Search.call(
      set_code: params[:set_code],
      card_number: params[:card_number],
      query: params[:q],
      user: current_user
    )

    respond_to do |format|
      format.json { render json: { results: serialize_results(@results) } }
      format.turbo_stream { render_turbo_stream_results }
      format.html { render partial: 'card_scanner/scan_results', locals: { results: @results } }
    end
  end

  def add_to_collection
    perform_add_to_collection
    @card = MagicCard.find(params[:magic_card_id])
    @collection = Collection.find(params[:collection_id])

    respond_to do |format|
      format.turbo_stream { render_add_success }
      format.json { render json: { success: true, action: @result[:action], name: @result[:name] } }
    end
  end

  private

  def load_collections
    @collections = current_user.collections
                               .where(collection_type: 'collection')
                               .order(:name)
  end

  def render_turbo_stream_results
    render turbo_stream: turbo_stream.replace(
      'scan_results',
      partial: 'card_scanner/scan_results',
      locals: { results: @results }
    )
  end

  def perform_add_to_collection
    @result = CollectionRecord::CreateOrUpdate.call(params: add_to_collection_params)
  end

  def add_to_collection_params
    {
      collection_id: params[:collection_id],
      magic_card_id: params[:magic_card_id],
      card_uuid: params[:card_uuid]
    }.merge(merged_quantities)
  end

  def merged_quantities
    current = current_quantities
    quantity_keys.index_with { |key| current[key] + params[key].to_i }
  end

  def current_quantities
    record = CollectionMagicCard.find_by(
      collection_id: params[:collection_id],
      magic_card_id: params[:magic_card_id]
    )
    quantity_keys.index_with { |key| record&.send(key).to_i }
  end

  def quantity_keys
    %i[quantity foil_quantity proxy_quantity proxy_foil_quantity]
  end

  def render_add_success
    flash.now[:type] = 'success'
    render turbo_stream: [
      turbo_stream.prepend('scan_history', partial: 'card_scanner/history_item', locals: history_locals),
      turbo_stream.append('toasts', partial: 'shared/toast', locals: toast_locals)
    ]
  end

  def history_locals
    {
      card: @card,
      collection: @collection,
      quantity: total_quantity_added,
      foil: params[:foil_quantity].to_i.positive?,
      proxy: params[:proxy_quantity].to_i.positive?,
      proxy_foil: params[:proxy_foil_quantity].to_i.positive?
    }
  end

  def total_quantity_added
    params[:quantity].to_i + params[:foil_quantity].to_i +
      params[:proxy_quantity].to_i + params[:proxy_foil_quantity].to_i
  end

  def toast_locals
    { message: "Added #{@card.name} to #{@collection.name}" }
  end
end
