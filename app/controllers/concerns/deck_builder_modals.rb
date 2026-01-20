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

  def swap_source_modal
    card = @deck.collection_magic_cards.staged.find(params[:card_id])
    available_sources = DeckBuilder::FindAvailableSources.call(card: card, user: current_user, deck: @deck)
    render partial: 'deck_builder/swap_source_modal', locals: {
      card: card,
      deck: @deck,
      available_sources: available_sources
    }
  end

  def edit_staged_modal
    card = @deck.collection_magic_cards.staged.find(params[:card_id])
    available = DeckBuilder::CalculateEditAvailability.call(card: card)
    max_quantities = calculate_max_quantities(card, available)

    render partial: 'deck_builder/edit_staged_modal', locals: {
      card: card,
      deck: @deck,
      available_quantities: available,
      max_quantities: max_quantities
    }
  end

  def view_card_modal
    card = @deck.collection_magic_cards.find(params[:card_id])
    magic_card = card.magic_card
    user_copies = find_user_copies(magic_card)

    render partial: 'deck_builder/view_card_modal', locals: {
      card: card,
      deck: @deck,
      magic_card: magic_card,
      user_copies: user_copies
    }
  end

  private

  def calculate_max_quantities(card, available)
    {
      regular: card.staged_quantity + (available[:regular] || 0),
      foil: card.staged_foil_quantity + (available[:foil] || 0),
      proxy: card.staged_proxy_quantity + (available[:proxy] || 0),
      proxy_foil: card.staged_proxy_foil_quantity + (available[:proxy_foil] || 0)
    }
  end

  def find_user_copies(magic_card)
    oracle_id = magic_card.scryfall_oracle_id
    return [] if oracle_id.blank?

    printing_ids = MagicCard.where(scryfall_oracle_id: oracle_id).pluck(:id)

    CollectionMagicCard
      .joins(:collection, :magic_card)
      .includes(:collection, magic_card: :boxset)
      .where(collections: { user_id: current_user.id })
      .where(magic_card_id: printing_ids, staged: false, needed: false)
      .order('collections.name')
  end
end
