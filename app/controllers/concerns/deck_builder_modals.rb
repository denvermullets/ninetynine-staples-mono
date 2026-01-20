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

  def swap_source_modal
    card = @deck.collection_magic_cards.staged.find(params[:card_id])
    available_sources = find_available_sources(card)
    render partial: 'deck_builder/swap_source_modal', locals: {
      card: card,
      deck: @deck,
      available_sources: available_sources
    }
  end

  def edit_staged_modal
    card = @deck.collection_magic_cards.staged.find(params[:card_id])
    available_quantities = calculate_available_for_edit(card)

    # Max includes current staged amounts + available
    max_quantities = {
      regular: card.staged_quantity + (available_quantities[:regular] || 0),
      foil: card.staged_foil_quantity + (available_quantities[:foil] || 0),
      proxy: card.staged_proxy_quantity + (available_quantities[:proxy] || 0),
      proxy_foil: card.staged_proxy_foil_quantity + (available_quantities[:proxy_foil] || 0)
    }

    render partial: 'deck_builder/edit_staged_modal', locals: {
      card: card,
      deck: @deck,
      available_quantities: available_quantities,
      max_quantities: max_quantities
    }
  end

  def view_card_modal
    card = @deck.collection_magic_cards.find(params[:card_id])
    magic_card = card.magic_card

    # Get all user's copies of this card (by oracle_id)
    oracle_id = magic_card.scryfall_oracle_id
    user_copies = if oracle_id.present?
                    printing_ids = MagicCard.where(scryfall_oracle_id: oracle_id).pluck(:id)
                    CollectionMagicCard
                      .joins(:collection, :magic_card)
                      .includes(:collection, magic_card: :boxset)
                      .where(collections: { user_id: current_user.id })
                      .where(magic_card_id: printing_ids, staged: false, needed: false)
                      .order('collections.name')
                  else
                    []
                  end

    render partial: 'deck_builder/view_card_modal', locals: {
      card: card,
      deck: @deck,
      magic_card: magic_card,
      user_copies: user_copies
    }
  end

  private

  def calculate_available_for_edit(card)
    return {} unless card.source_collection_id

    source = CollectionMagicCard.find_by(
      collection_id: card.source_collection_id,
      magic_card_id: card.magic_card_id,
      staged: false,
      needed: false
    )

    return {} unless source

    # Get amounts already staged from this source (excluding current card)
    other_staged = CollectionMagicCard.staged
      .where(source_collection_id: card.source_collection_id, magic_card_id: card.magic_card_id)
      .where.not(id: card.id)

    other_staged_regular = other_staged.sum(:staged_quantity)
    other_staged_foil = other_staged.sum(:staged_foil_quantity)
    other_staged_proxy = other_staged.sum(:staged_proxy_quantity)
    other_staged_proxy_foil = other_staged.sum(:staged_proxy_foil_quantity)

    {
      regular: [source.quantity - other_staged_regular, 0].max,
      foil: [source.foil_quantity - other_staged_foil, 0].max,
      proxy: [(source.proxy_quantity || 0) - other_staged_proxy, 0].max,
      proxy_foil: [(source.proxy_foil_quantity || 0) - other_staged_proxy_foil, 0].max
    }
  end

  def find_available_sources(card)
    magic_card = card.magic_card
    oracle_id = magic_card.scryfall_oracle_id
    total_needed = card.total_staged

    # Find all printings of this card by oracle_id
    printing_ids = MagicCard.where(scryfall_oracle_id: oracle_id).pluck(:id)

    user_copies = CollectionMagicCard
      .joins(:collection, :magic_card)
      .includes(:collection, magic_card: :boxset)
      .where(collections: { user_id: current_user.id })
      .where(magic_card_id: printing_ids, staged: false, needed: false)
      .where.not(collection_id: @deck.id)

    user_copies.filter_map do |cmc|
      staged_from_source = CollectionMagicCard.staged
        .where(source_collection_id: cmc.collection_id, magic_card_id: cmc.magic_card_id)
        .where.not(id: card.id)

      already_staged = staged_from_source.sum(:staged_quantity) +
                       staged_from_source.sum(:staged_foil_quantity) +
                       staged_from_source.sum(:staged_proxy_quantity) +
                       staged_from_source.sum(:staged_proxy_foil_quantity)

      regular = cmc.quantity
      foil = cmc.foil_quantity
      proxy = cmc.proxy_quantity || 0
      proxy_foil = cmc.proxy_foil_quantity || 0
      total_available = regular + foil + proxy + proxy_foil - already_staged

      next if total_available < total_needed

      {
        collection_id: cmc.collection_id,
        collection_name: cmc.collection.name,
        magic_card: cmc.magic_card,
        regular: regular,
        foil: foil,
        proxy: proxy,
        proxy_foil: proxy_foil,
        total_available: total_available,
        is_current: cmc.collection_id == card.source_collection_id && cmc.magic_card_id == card.magic_card_id
      }
    end
  end
end
