class MagicCard < ApplicationRecord
  belongs_to :boxset

  has_many :printings

  has_one :card_price
  has_one :magic_card_identifier

  has_many :magic_card_artists
  has_many :artists, through: :magic_card_artists

  has_many :magic_card_sub_types
  has_many :sub_types, through: :magic_card_sub_types

  has_many :magic_card_super_types
  has_many :super_types, through: :magic_card_super_types

  has_many :magic_card_types
  has_many :card_types, through: :magic_card_types

  has_many :collection_magic_cards, dependent: :destroy
  has_many :collections, through: :collection_magic_cards
  has_many :want_list_items, dependent: :delete_all

  has_many :magic_card_colors
  has_many :colors, through: :magic_card_colors

  has_many :magic_card_color_idents
  has_many :colors, through: :magic_card_color_idents

  has_many :magic_card_rulings
  has_many :rulings, through: :magic_card_rulings

  has_many :magic_card_keywords
  has_many :keywords, through: :magic_card_keywords

  has_many :magic_card_legalities, dependent: :destroy
  has_many :legalities, through: :magic_card_legalities

  has_many :magic_card_finishes
  has_many :finishes, through: :magic_card_finishes

  has_many :magic_card_frame_effects
  has_many :frame_effects, through: :magic_card_frame_effects

  has_many :magic_card_variations
  has_many :variations, through: :magic_card_variations, source: :variation

  has_one :game_changer, primary_key: :scryfall_oracle_id, foreign_key: :oracle_id
  has_many :card_roles, primary_key: :scryfall_oracle_id, foreign_key: :scryfall_oracle_id
  has_many :card_oracle_tags, primary_key: :scryfall_oracle_id, foreign_key: :scryfall_oracle_id
  has_many :oracle_tags, through: :card_oracle_tags

  has_many :tracked_decks_as_commander, class_name: 'TrackedDeck', foreign_key: :commander_id
  has_many :tracked_decks_as_partner, class_name: 'TrackedDeck', foreign_key: :partner_commander_id
  has_many :game_opponents_as_commander, class_name: 'GameOpponent', foreign_key: :commander_id
  has_many :game_opponents_as_partner, class_name: 'GameOpponent', foreign_key: :partner_commander_id

  # Every suggestion surface has to answer "is this even legal in the format" and the answer lives two
  # joins away, so it is a scope rather than a copy of the join in each caller.
  scope :commander_legal, lambda {
    where(id: MagicCardLegality.joins(:legality)
                               .where(legalities: { name: 'commander' }, status: 'Legal')
                               .select(:magic_card_id))
  }

  # Searching by name has to reach the alternate name some printings carry (flavor_name - "Balin's
  # Tomb" on an Ancient Tomb) or those printings cannot be found under the name on the cardboard.
  # SQL rather than a scope because the searches run it against relations rooted on other tables.
  NAME_MATCH = '(magic_cards.name ILIKE :name OR magic_cards.flavor_name ILIKE :name)'.freeze

  def self.name_containing(term)
    [NAME_MATCH, { name: "%#{sanitize_sql_like(term.to_s)}%" }]
  end

  def other_face
    return nil unless other_face_uuid.present?

    MagicCard.find_by(card_uuid: other_face_uuid)
  end

  def double_faced?
    other_face_uuid.present?
  end

  # Ingestion stores each face of a double-faced printing as its own row, but everywhere a card is
  # owned, traded or wanted it is one card, and the front face ('a') stands for it.
  def front_face
    return self unless card_side == 'b'

    other_face || self
  end

  def price_change
    price_trend_service.price_change
  end

  def price_trend(days: 7, threshold_percent: 5.0)
    price_trend_service.trend(days: days, threshold_percent: threshold_percent)
  end

  # Build mode helper methods
  def user_owned_copies(user)
    return [] unless user

    collection_magic_cards
      .joins(:collection)
      .where(collections: { user_id: user.id }, staged: false, needed: false)
      .includes(:collection)
  end

  # Rows in the user's collections holding a different printing of this same card.
  # magic_cards rows are per-printing, so the expanded card row would otherwise give
  # no hint that the same card is sitting in another location under a different set.
  def other_printing_locations(user)
    return CollectionMagicCard.none if user.nil? || scryfall_oracle_id.blank?

    CollectionMagicCard
      .joins(:collection)
      .joins(magic_card: :boxset)
      .where(collections: { user_id: user.id })
      .where(magic_cards: { scryfall_oracle_id: scryfall_oracle_id, card_side: [nil, 'a'] })
      .where.not(magic_card_id: id)
      .preload(:collection, magic_card: :boxset)
      .order('boxsets.release_date DESC NULLS LAST, collections.name ASC')
  end

  # The user's want row this printing would satisfy, preferring one that names this exact printing
  # over an any-printing row that happens to point at a different one. The unique indexes allow at
  # most one of each, so this loads two rows at most.
  def want_list_item_for(user)
    return nil if user.nil?

    printing_id = front_face.id
    items = WantListItem.where(user_id: user.id).matching(self).to_a
    items.find { |item| item.magic_card_id == printing_id } || items.first
  end

  def wanted_by?(user)
    return false if user.nil?

    WantListItem.where(user_id: user.id).matching(self).exists?
  end

  def primary_type
    types = %w[Creature Artifact Enchantment Instant Sorcery Land Planeswalker Battle]
    types.find { |t| card_type&.include?(t) } || card_type&.split(' - ')&.first
  end

  # `.includes` on the association queries even when it is preloaded - once per card when a whole deck
  # is grouped by color identity - so a loaded association is read as it is
  def color_identity_string
    idents = magic_card_color_idents
    idents = idents.includes(:color) unless association(:magic_card_color_idents).loaded?
    idents.map { |mci| mci.color.name }.sort.join
  end

  # exists? ignores an already-loaded :finishes association and re-queries on every call, so a card
  # row paid one query per predicate per call site. Reading the names off the association means a
  # preload - or failing that, the first call - covers every later check on the same card.
  def finish_names
    finishes.map(&:name)
  end

  def foil_available?
    finish_names.intersect?(%w[foil etched])
  end

  def non_foil_available?
    finish_names.include?('nonfoil')
  end

  def etched_finish?
    finish_names.include?('etched')
  end

  # Returns the best available price for display purposes
  # Falls back to foil_price for foil-only cards
  def display_price
    return normal_price if normal_price.to_f.positive?

    foil_price.to_f
  end

  # Proxy price helpers — proxies are stand-ins so their value should reflect
  # whatever price data exists for the card, falling back across finish types.
  def proxy_normal_price
    normal_price.to_f.positive? ? normal_price.to_f : foil_price.to_f
  end

  def proxy_foil_price
    foil_price.to_f.positive? ? foil_price.to_f : normal_price.to_f
  end

  private

  def price_trend_service
    @price_trend_service ||= MagicCards::PriceTrend.new(price_history)
  end
end
