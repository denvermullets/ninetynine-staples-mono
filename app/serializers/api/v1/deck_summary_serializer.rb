# A deck as the client's deck picker shows it: no card list, just enough to pick one. The deck show
# endpoint nests the same object under `deck`.
#
# Serialize a page of decks with .many - card counts, commanders and covers load in a fixed number of
# queries however many decks there are. new(deck) is for one deck.
class Api::V1::DeckSummarySerializer
  COLOR_ORDER = Api::V1::CardSerializer::COLOR_ORDER
  PLACEHOLDER_IMAGE = Api::V1::CardSerializer::PLACEHOLDER_IMAGE

  def self.many(decks)
    decks = decks.to_a
    return [] if decks.empty?

    ids = decks.map(&:id)
    counts = CollectionMagicCard.decklist_counts(ids)
    commanders = load_commanders(ids)
    ActiveRecord::Associations::Preloader.new(records: decks, associations: :cover_card).call

    decks.map do |deck|
      new(deck, card_count: counts.fetch(deck.id, 0), commanders: commanders.fetch(deck.id, [])).summary_json
    end
  end

  # { collection_id => [MagicCard] }, in the order they were added
  def self.load_commanders(collection_ids)
    CollectionMagicCard.commanders.where(collection_id: collection_ids)
                       .includes(magic_card: :color_identities).order(:id)
                       .group_by(&:collection_id)
                       .transform_values { |rows| rows.map(&:magic_card).uniq }
  end

  private_class_method :load_commanders

  # the commanders, their color identity and the cover fallback, as every deck summary shows them -
  # precon summaries share these
  def self.commander_json(card)
    { card_uuid: card.card_uuid, oracle_id: card.scryfall_oracle_id, name: card.name,
      image_art_crop: image_url(card.art_crop), image_normal: image_url(card.image_medium) }
  end

  # the union of the commanders' identities, so a deck with no commander has none
  def self.color_identity(commanders)
    commanders.flat_map { |card| card.color_identities.map(&:name) }.uniq
              .sort_by { |name| COLOR_ORDER.index(name) || COLOR_ORDER.length }
  end

  def self.image_url(url)
    url.presence unless url.to_s.include?(PLACEHOLDER_IMAGE)
  end

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
    {
      id: @deck.id,
      name: @deck.name,
      collection_type: @deck.collection_type,
      is_public: @deck.is_public,
      bracket_level: @deck.bracket_level,
      card_count: @card_count,
      commanders: @commanders.map { |card| self.class.commander_json(card) },
      color_identity: self.class.color_identity(@commanders),
      cover_image: cover_image,
      updated_at: @deck.updated_at
    }
  end

  private

  # art crop of the chosen cover card, falling back to the first commander that has one
  def cover_image
    self.class.image_url(@deck.cover_card&.art_crop) ||
      @commanders.filter_map { |card| self.class.image_url(card.art_crop) }.first
  end
end
