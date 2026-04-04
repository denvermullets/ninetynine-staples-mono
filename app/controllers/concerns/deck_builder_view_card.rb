module DeckBuilderViewCard
  extend ActiveSupport::Concern

  def view_card
    if @deck.hidden? && !@is_owner
      redirect_to root_path, alert: 'This deck is private'
      return
    end

    @card = @deck.collection_magic_cards.find(params[:card_id])
    @magic_card = @card.magic_card
    @user_copies = current_user ? DeckBuilder::FindUserCopies.call(magic_card: @magic_card, user: current_user) : []
    @price_extremes = MagicCards::PriceExtremes.call(@magic_card.price_history)
  end
end
