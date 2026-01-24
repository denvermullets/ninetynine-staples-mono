class CardScannerController < ApplicationController
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
                               .where.not('collection_type = ? OR collection_type LIKE ?', 'deck', '%_deck')
                               .order(:name)
  end

  def serialize_results(results)
    results.map { |result| serialize_card_result(result) }
  end

  def serialize_card_result(result)
    card = result[:card]
    owned = result[:owned] || {}
    {
      card: card_json(card),
      owned: {
        quantity: owned[:quantity] || 0,
        foil_quantity: owned[:foil_quantity] || 0,
        proxy_quantity: owned[:proxy_quantity] || 0,
        proxy_foil_quantity: owned[:proxy_foil_quantity] || 0
      }
    }
  end

  def card_json(card)
    {
      id: card.id,
      name: card.name,
      card_uuid: card.card_uuid,
      card_number: card.card_number,
      boxset_name: card.boxset&.name,
      boxset_code: card.boxset&.code,
      image_small: card.image_small,
      image_large: card.image_large,
      normal_price: card.normal_price.to_f,
      foil_price: card.foil_price.to_f,
      has_foil: card.foil_available?,
      has_non_foil: card.non_foil_available?
    }
  end

  def render_turbo_stream_results
    render turbo_stream: turbo_stream.replace(
      'scan_results',
      partial: 'card_scanner/scan_results',
      locals: { results: @results }
    )
  end

  def perform_add_to_collection
    current = current_quantities
    @result = CollectionRecord::CreateOrUpdate.call(
      params: {
        collection_id: params[:collection_id],
        magic_card_id: params[:magic_card_id],
        quantity: current[:quantity] + params[:quantity].to_i,
        foil_quantity: current[:foil_quantity] + params[:foil_quantity].to_i,
        proxy_quantity: current[:proxy_quantity] + params[:proxy_quantity].to_i,
        proxy_foil_quantity: current[:proxy_foil_quantity] + params[:proxy_foil_quantity].to_i,
        card_uuid: params[:card_uuid]
      }
    )
  end

  def current_quantities
    record = CollectionMagicCard.find_by(
      collection_id: params[:collection_id],
      magic_card_id: params[:magic_card_id]
    )
    return { quantity: 0, foil_quantity: 0, proxy_quantity: 0, proxy_foil_quantity: 0 } unless record

    {
      quantity: record.quantity,
      foil_quantity: record.foil_quantity,
      proxy_quantity: record.proxy_quantity,
      proxy_foil_quantity: record.proxy_foil_quantity
    }
  end

  def render_add_success
    flash.now[:type] = 'success'
    render turbo_stream: [
      turbo_stream.append('scan_history', partial: 'card_scanner/history_item', locals: history_locals),
      turbo_stream.append('toasts', partial: 'shared/toast', locals: toast_locals)
    ]
  end

  def history_locals
    qty = params[:quantity].to_i
    foil_qty = params[:foil_quantity].to_i
    proxy_qty = params[:proxy_quantity].to_i
    proxy_foil_qty = params[:proxy_foil_quantity].to_i

    {
      card: @card,
      collection: @collection,
      quantity: qty + foil_qty + proxy_qty + proxy_foil_qty,
      foil: foil_qty.positive?,
      proxy: proxy_qty.positive?,
      proxy_foil: proxy_foil_qty.positive?
    }
  end

  def toast_locals
    { message: "Added #{@card.name} to #{@collection.name}" }
  end
end
