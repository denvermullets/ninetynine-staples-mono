# The card as the game client builds a CardDefinition from it: one entry per printing, with every face
# of a multi-face card nested under `faces`. magic_cards stores each face as its own row, linked through
# other_face_uuid, so a card is assembled from the row it was given plus the rows that names.
#
# Serialize a deck's worth with .many - the other faces come back in one query and every row shares one
# preload pass, so the query count does not grow with the number of cards. new(card) is for one card.
class Api::V1::CardSerializer
  # Scryfall's stand-in for art that is not out yet - the client shows its own fallback instead
  PLACEHOLDER_IMAGE = 'errors.scryfall.com/soon.jpg'.freeze
  COLOR_ORDER = %w[W U B R G].freeze

  def self.many(cards, rulings: false)
    cards = cards.to_a
    face_rows = load_face_rows(cards)
    groups = cards.map { |card| face_group(card, face_rows) }

    ActiveRecord::Associations::Preloader.new(records: (cards + face_rows.values).uniq,
                                              associations: MagicCard::API_PRELOADS).call
    if rulings
      ActiveRecord::Associations::Preloader.new(records: groups.map(&:first).uniq,
                                                associations: :rulings).call
    end

    groups.map { |anchor, faces| new(anchor, faces: faces, rulings: rulings).card_json }
  end

  def self.load_face_rows(cards)
    uuids = cards.flat_map { |card| other_face_uuids(card) }.uniq
    return {} if uuids.empty?

    MagicCard.where(card_uuid: uuids).index_by(&:card_uuid)
  end

  def self.other_face_uuids(card)
    card.other_face_uuid.to_s.split(',').map(&:strip).compact_blank
  end

  # -> [anchor, faces]. The anchor is the front face and carries the card-level fields, whichever face
  # the caller handed over. A meld result names both of the cards that meld into it, but it is a card of
  # its own rather than a back face of either, so it stands alone.
  def self.face_group(card, face_rows)
    return [card, [card]] if card.layout == 'meld' && card.card_side == 'b'

    faces = [card, *other_face_uuids(card).filter_map { |uuid| face_rows[uuid] }].uniq.sort_by { |f| f.card_side.to_s }
    [front_of(card, faces), faces]
  end

  def self.front_of(card, faces)
    return card if card.card_side.nil? || card.card_side == 'a'

    faces.find { |face| face.card_side == 'a' } || card
  end

  private_class_method :load_face_rows, :other_face_uuids, :face_group, :front_of

  def initialize(card, faces: nil, rulings: false)
    @card = card
    @faces = faces
    @rulings = rulings
  end

  def as_json(*)
    return card_json if @faces

    self.class.many([@card], rulings: @rulings).first
  end

  def card_json
    json = {
      card_uuid: @card.card_uuid,
      oracle_id: @card.scryfall_oracle_id,
      name: @card.name,
      layout: @card.layout,
      set: { code: @card.boxset&.code, name: @card.boxset&.name, card_number: @card.card_number },
      rarity: @card.rarity,
      is_token: @card.is_token,
      can_be_commander: @card.can_be_commander,
      commander_legality: @card.commander_legality&.status,
      color_identity: color_names(@card.color_identities),
      edhrec_rank: @card.edhrec_rank,
      faces: @faces.map { |face| face_json(face) }
    }
    json[:rulings] = rulings_json if @rulings
    json
  end

  private

  def face_json(face)
    {
      side: face.card_side || 'a',
      name: face.face_name.presence || face.name,
      mana_cost: face.mana_cost,
      # stored once per card, so every face of a split or adventure card carries the combined value
      mana_value: face.mana_value&.to_f,
      type_line: face.card_type,
      **types_json(face),
      oracle_text: face.text,
      power: face.power,
      toughness: face.toughness,
      # no columns for these yet - try reads them once they exist and returns nil until then
      loyalty: face.try(:loyalty),
      defense: face.try(:defense),
      colors: color_names(face.colors),
      keywords: face.keywords.map(&:keyword).sort,
      images: images_json(face)
    }
  end

  def types_json(face)
    { supertypes: type_names(face, face.super_types), types: type_names(face, face.card_types),
      subtypes: type_names(face, face.sub_types) }
  end

  # in the order they appear on the type line ("Artifact Creature", not whatever order the join rows load)
  def type_names(face, types)
    line = face.card_type.to_s
    types.map(&:name).sort_by { |name| [line.index(name) || line.length, name] }
  end

  def color_names(colors)
    colors.map(&:name).sort_by { |name| COLOR_ORDER.index(name) || COLOR_ORDER.length }
  end

  # image_medium is Scryfall's "normal" size, so it goes out under that name
  def images_json(face)
    { small: image_url(face.image_small), normal: image_url(face.image_medium),
      large: image_url(face.image_large), art_crop: image_url(face.art_crop) }
  end

  def image_url(url)
    url.presence unless url.to_s.include?(PLACEHOLDER_IMAGE)
  end

  def rulings_json
    @card.rulings.sort_by { |r| [r.ruling_date || Date.new(0), r.id] }
         .map { |r| { date: r.ruling_date&.iso8601, text: r.ruling } }
  end
end
