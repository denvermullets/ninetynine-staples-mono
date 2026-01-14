module DeckBuilderModals
  extend ActiveSupport::Concern

  def confirm_remove_modal
    card = @deck.collection_magic_cards.find(params[:card_id])
    render partial: 'deck_builder/confirm_modal', locals: {
      title: 'Remove Card',
      message: "Remove #{card.magic_card.name} from deck?",
      confirm_text: 'Remove',
      confirm_url: remove_card_deck_builder_path(@deck, card_id: card.id),
      confirm_method: :delete,
      danger: true
    }
  end

  def confirm_finalize_modal
    render partial: 'deck_builder/confirm_modal', locals: {
      title: 'Finalize Deck',
      message: 'This will move cards from source collections. Planned cards will remain staged. Continue?',
      confirm_text: 'Finalize',
      confirm_url: finalize_deck_builder_path(@deck),
      confirm_method: :post,
      danger: false
    }
  end
end
