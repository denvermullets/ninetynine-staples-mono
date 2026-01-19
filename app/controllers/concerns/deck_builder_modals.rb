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

  def edit_deck_modal
    render partial: 'deck_builder/edit_deck_modal', locals: { deck: @deck }
  end

  def transfer_card_modal
    card = @deck.collection_magic_cards.find(params[:card_id])
    # For finalized cards, we need to show collections to transfer to
    collections = current_user.collections.where.not(id: @deck.id).order(:name)
    render partial: 'deck_builder/transfer_card_modal', locals: {
      card: card,
      deck: @deck,
      collections: collections
    }
  end

  def swap_printing_modal
    card = @deck.collection_magic_cards.find(params[:card_id])
    printings = MagicCard.where(scryfall_oracle_id: card.magic_card.scryfall_oracle_id)
                         .includes(:boxset)
                         .order('boxsets.release_date DESC')
    render partial: 'deck_builder/swap_printing_modal', locals: {
      card: card,
      deck: @deck,
      printings: printings
    }
  end
end
