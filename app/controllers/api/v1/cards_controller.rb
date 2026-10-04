# Cards on their own rather than as part of a deck: the client looks them up to conjure a card in the
# sandbox, load a scenario file, or refresh a cached definition
class Api::V1::CardsController < Api::V1::BaseController
  BATCH_KEYS = %i[oracle_ids card_uuids].freeze
  MAX_BATCH = 200
  UUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

  # full card objects for up to MAX_BATCH oracle ids or card uuids, in the order they were asked for.
  # An oracle id gets its canonical printing (MagicCard::CANONICAL_PRINTING_ORDER). Ids that match
  # nothing come back in `missing` instead of failing the request
  def batch
    given = BATCH_KEYS.select { |key| params.key?(key) }
    if given.many?
      return render_error(:unprocessable_content, 'invalid_parameter', 'Send oracle_ids or card_uuids, not both')
    end

    key = given.first || BATCH_KEYS.first
    ids = batch_ids(key)
    if ids.size > MAX_BATCH
      return render_error(:unprocessable_content, 'too_many_ids', "At most #{MAX_BATCH} #{key} per request")
    end

    render json: batch_json(ids, key == :oracle_ids ? cards_by_oracle_id(ids) : cards_by_uuid(ids))
  end

  # name search, one result per card (its canonical printing), exact name first. Tokens only with
  # ?token=true, otherwise no tokens
  def search
    query = params.require(:q).to_s.strip
    scope = MagicCard.where(is_token: params[:token] == 'true')
                     .where(*MagicCard.name_containing(query))
                     .canonical_printings
                     .order(*name_relevance(query))
    cards, meta = paginate(scope)
    render json: { data: Api::V1::CardSummarySerializer.many(cards), meta: meta }
  end

  private

  def batch_ids(key)
    Array.wrap(params.require(key)).map(&:to_s).compact_blank.uniq
  end

  # found is { downcased id => card }
  def batch_json(ids, found)
    cards = ids.filter_map { |id| found[id.downcase] }
    { cards: Api::V1::CardSerializer.many(cards, rulings: params[:include] == 'rulings'),
      missing: ids.reject { |id| found.key?(id.downcase) } }
  end

  # { downcased oracle id => canonical printing }. Anything that isn't a uuid can't match and would make
  # the uuid column cast it to NULL, so it never reaches the query
  def cards_by_oracle_id(ids)
    oracle_ids = ids.map(&:downcase).grep(UUID_FORMAT)
    return {} if oracle_ids.empty?

    MagicCard.where(scryfall_oracle_id: oracle_ids)
             .canonical_printings
             .index_by(&:scryfall_oracle_id)
  end

  # { downcased card uuid => printing }
  def cards_by_uuid(ids)
    MagicCard.where(card_uuid: ids.map(&:downcase)).index_by { |card| card.card_uuid.downcase }
  end

  # exact name, then names starting with the query, then the rest, alphabetically within each
  def name_relevance(query)
    exact = MagicCard.sanitize_sql_array(['LOWER(magic_cards.name) = LOWER(?) DESC', query])
    prefix = MagicCard.sanitize_sql_array(['magic_cards.name ILIKE ? DESC', "#{MagicCard.sanitize_sql_like(query)}%"])
    [Arel.sql(exact), Arel.sql(prefix), :name, :id]
  end
end
