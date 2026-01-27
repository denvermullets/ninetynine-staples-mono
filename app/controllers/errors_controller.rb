class ErrorsController < ApplicationController
  layout 'errors'

  def not_found
    @error_code = '404'
    @error_title = 'Page not found'
    @error_message = "Sorry, the page you are looking for doesn't exist or has been moved. Here are some helpful links:"
    @salty_card = random_salty_card
    render status: :not_found
  end

  def unprocessable_entity
    @error_code = '422'
    @error_title = 'Unprocessable entity'
    @error_message = "Sorry, we couldn't process your request. Here are some helpful links:"
    @salty_card = random_salty_card
    render status: :unprocessable_entity
  end

  def internal_server_error
    @error_code = '500'
    @error_title = 'Something went wrong'
    @error_message = "We're sorry, but something unexpected happened. Please try again later."
    @salty_card = random_salty_card
    render status: :internal_server_error
  end

  private

  def random_salty_card
    MagicCard
      .where.not(edhrec_saltiness: nil)
      .where.not(image_large: [nil, ''])
      .order(edhrec_saltiness: :desc, created_at: :desc)
      .limit(500)
      .uniq(&:scryfall_oracle_id)
      .first(100)
      .sample
  rescue StandardError
    nil
  end
end
