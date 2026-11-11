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
    @copy_back_faces = back_faces_for(@user_copies)
    @price_extremes = MagicCards::PriceExtremes.call(@magic_card.price_history)
  end

  private

  # hovering a copy of a double-faced card swaps both faces, so each copy's back is looked up here
  # in one query rather than once per row
  def back_faces_for(copies)
    uuids = copies.filter_map { |copy| copy.magic_card.other_face_uuid }
    return {} if uuids.empty?

    MagicCard.where(card_uuid: uuids).index_by(&:card_uuid)
  end
end
