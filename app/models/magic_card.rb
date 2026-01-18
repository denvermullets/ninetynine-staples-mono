class MagicCard < ApplicationRecord
  belongs_to :boxset

  has_many :printings

  has_one :card_price

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

  has_many :tracked_decks_as_commander, class_name: 'TrackedDeck', foreign_key: :commander_id
  has_many :tracked_decks_as_partner, class_name: 'TrackedDeck', foreign_key: :partner_commander_id
  has_many :game_opponents_as_commander, class_name: 'GameOpponent', foreign_key: :commander_id
  has_many :game_opponents_as_partner, class_name: 'GameOpponent', foreign_key: :partner_commander_id

  def other_face
    return nil unless other_face_uuid.present?

    MagicCard.find_by(card_uuid: other_face_uuid)
  end

  def double_faced?
    other_face_uuid.present?
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

  def primary_type
    types = %w[Creature Artifact Enchantment Instant Sorcery Land Planeswalker Battle]
    types.find { |t| card_type&.include?(t) } || card_type&.split(' - ')&.first
  end

  def color_identity_string
    magic_card_color_idents.includes(:color).map { |mci| mci.color.name }.sort.join
  end

  def foil_available?
    has_foil || finishes.exists?(name: 'etched')
  end

  def non_foil_available?
    has_non_foil
  end

  def etched_finish?
    finishes.exists?(name: 'etched')
  end

  # Returns the best available price for display purposes
  # Falls back to foil_price for foil-only cards
  def display_price
    return normal_price if normal_price.to_f.positive?

    foil_price.to_f
  end

  private

  def price_trend_service
    @price_trend_service ||= MagicCards::PriceTrend.new(price_history)
  end
end
