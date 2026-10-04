# A Commander precon as the client's opponent picker shows it: the user deck summary's commander,
# identity and cover fields, with the precon's own code and release date in place of the
# collection fields. The precon show endpoint nests the same object under `deck`.
#
# Serialize a page of precons with .many - card counts and commanders load in a fixed number of
# queries however many decks there are. new(deck) is for one deck.
class Api::V1::PreconDeckSummarySerializer
  def self.many(decks)
    decks = decks.to_a
    return [] if decks.empty?

    ids = decks.map(&:id)
    counts = PreconDeckCard.card_counts(ids)
    commanders = load_commanders(ids)

    decks.map do |deck|
      new(deck, card_count: counts.fetch(deck.id, 0), commanders: commanders.fetch(deck.id, [])).summary_json
    end
  end

  # { precon_deck_id => [MagicCard] }, in the order they were ingested
  def self.load_commanders(precon_deck_ids)
    PreconDeckCard.commanders.where(precon_deck_id: precon_deck_ids)
                  .includes(magic_card: :color_identities).order(:id)
                  .group_by(&:precon_deck_id)
                  .transform_values { |rows| rows.map(&:magic_card).uniq }
  end

  private_class_method :load_commanders

  def initialize(deck, card_count: nil, commanders: nil)
    @deck = deck
    @card_count = card_count
    @commanders = commanders
  end

  def as_json(*)
    return summary_json if @commanders

    self.class.many([@deck]).first
  end

  def summary_json
    summary = Api::V1::DeckSummarySerializer
    {
      id: @deck.id,
      name: @deck.name,
      code: @deck.code,
      release_date: @deck.release_date,
      card_count: @card_count,
      commanders: @commanders.map { |card| summary.commander_json(card) },
      color_identity: summary.color_identity(@commanders),
      cover_image: @commanders.filter_map { |card| summary.image_url(card.art_crop) }.first
    }
  end
end
