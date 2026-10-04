class Api::V1::DecksController < Api::V1::BaseController
  # the signed-in user's decks, most recently changed first. ?type=commander narrows to commander decks
  def index
    decks, meta = paginate(deck_scope)
    render json: { data: Api::V1::DeckSummarySerializer.many(decks), meta: meta }
  end

  # one deck with its cards: the user's own, or anyone's public deck. Someone else's private deck is a
  # 404, same as a deck that doesn't exist. Answers 304 to a client whose copy is still current
  def show
    deck = visible_decks.find(params[:id])
    return unless stale?(**cache_validators(deck))

    render json: Api::V1::DeckSerializer.new(deck, rulings: params[:include] == 'rulings')
  end

  private

  def deck_scope
    scope = current_api_user.collections.decks.order(updated_at: :desc, id: :desc)
    scope = scope.by_type('commander_deck') if params[:type] == 'commander'
    scope
  end

  def visible_decks
    Collection.decks.where(user_id: current_api_user.id).or(Collection.decks.visible_to_public)
  end

  # Last-Modified is the newest of the deck, its rows and their cards. The ETag keeps each of those to
  # the microsecond (Last-Modified only has whole seconds) plus the row count, since removing a row
  # changes the deck without touching any timestamp that is left
  def cache_validators(deck)
    rows_changed, cards_changed, row_count =
      deck.collection_magic_cards.joins(:magic_card)
          .pick(Arel.sql('MAX(collection_magic_cards.updated_at)'), Arel.sql('MAX(magic_cards.updated_at)'),
                Arel.sql('COUNT(*)'))
    stamps = [deck.updated_at, rows_changed, cards_changed]

    { etag: [deck.id, *stamps.map { |t| t&.utc&.iso8601(6) }, row_count, params[:include]],
      last_modified: stamps.compact.max }
  end
end
