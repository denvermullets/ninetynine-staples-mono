class CardScannerController < ApplicationController
  before_action :authenticate_user!
  before_action :load_collections, only: [:show]

  def show
    if @collections.empty?
      flash.now[:alert] = 'You need to create a collection first before scanning cards.'
    end
  end

  def search
    @results = CardScanner::Search.call(
      set_code: params[:set_code],
      card_number: params[:card_number],
      query: params[:q],
      user: current_user
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          'scan_results',
          partial: 'card_scanner/scan_results',
          locals: { results: @results }
        )
      end
      format.html do
        render partial: 'card_scanner/scan_results', locals: { results: @results }
      end
    end
  end

  def add_to_collection
    result = CollectionRecord::CreateOrUpdate.call(
      params: {
        collection_id: params[:collection_id],
        magic_card_id: params[:magic_card_id],
        quantity: params[:quantity] || 1,
        foil_quantity: params[:foil_quantity] || 0,
        proxy_quantity: 0,
        proxy_foil_quantity: 0,
        card_uuid: params[:card_uuid]
      }
    )

    card = MagicCard.find(params[:magic_card_id])
    collection = Collection.find(params[:collection_id])

    respond_to do |format|
      format.turbo_stream do
        flash.now[:type] = 'success'
        render turbo_stream: [
          turbo_stream.append('scan_history', partial: 'card_scanner/history_item', locals: {
            card: card,
            collection: collection,
            quantity: params[:quantity].to_i,
            foil: params[:foil_quantity].to_i > 0
          }),
          turbo_stream.append('toasts', partial: 'shared/toast', locals: {
            message: "Added #{card.name} to #{collection.name}"
          })
        ]
      end
      format.json do
        render json: { success: true, action: result[:action], name: result[:name] }
      end
    end
  end

  private

  def load_collections
    @collections = current_user.collections
                               .where.not('collection_type = ? OR collection_type LIKE ?', 'deck', '%_deck')
                               .order(:name)
  end
end
