module DeckBuilderBulkImport
  extend ActiveSupport::Concern

  def bulk_import
    render 'deck_builder/bulk_import'
  end

  def bulk_import_search
    results = DeckBuilder::Search.call(
      query: params[:name], user: current_user, deck: @deck, scope: 'all', limit: 20
    )

    exact = results.select { |r| r[:card].name.downcase == params[:name].to_s.downcase }
    results = exact.presence || results

    quantity = (params[:quantity] || 1).to_i
    render partial: 'deck_builder/bulk_import_card', locals: { results: results, deck: @deck, quantity: quantity }
  end
end
