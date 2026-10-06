# PriceAlert's band kind and the Card Kingdom buylist range that bands and movement rules share. See
# the PriceAlert header for what a band is, and PriceAlerts::SyncBand for how one is evaluated.
#
# A band has two lines: the threshold it reaches and the from price it comes back to. `above` and
# `below` bands list a card only on reaching the threshold, going up or down; coming back to the from
# price just re-arms it. A `both` band - the sleeve-swap one - lists both moves: up to the threshold
# and back down to the from price, which sits under it.
module PriceAlertBands
  extend ActiveSupport::Concern

  BAND_DIRECTIONS = %w[both above below].freeze
  MOVES = %w[up down].freeze

  included do
    has_many :band_cards, class_name: 'PriceBandCard', dependent: :delete_all, inverse_of: :band

    validate :buylist_range_in_order

    with_options if: :band? do
      validates :threshold_price, :from_price, presence: true
      validates :direction, inclusion: { in: BAND_DIRECTIONS }
      validates :magic_card_id, :scryfall_oracle_id, :window, :rarities, absence: true
      validate :from_price_before_threshold
    end

    scope :bands, -> { where(kind: 'band') }
  end

  def band?
    kind == 'band'
  end

  # a band that lists the move back to its from price as well as the move to its threshold
  def two_way?
    band? && direction == 'both'
  end

  # The way a card goes reaching the threshold: down for a `below` band, up otherwise
  def reach_move
    direction == 'below' ? 'down' : 'up'
  end

  def return_move
    reach_move == 'up' ? 'down' : 'up'
  end

  # Whether `price` has reached a band's threshold - landing on it counts going up, the same line
  # #side_for draws
  def reaches?(price)
    side_for(price) == (reach_move == 'up' ? 'above' : 'below')
  end

  # Whether `price` is back at the band's from price or past it. Landing on it counts.
  def returns_at?(price)
    return false if price.nil? || from_price.nil?

    reach_move == 'up' ? price <= from_price : price >= from_price
  end

  # Whether a card Card Kingdom pays `buylist` for falls in the range. A buylist of 0 or nil is CK
  # not buying, which no range lets through; with no range set, every card does.
  def buylist_in_range?(buylist)
    return true unless min_buylist_price || max_buylist_price
    return false unless buylist&.positive?

    buylist.between?(min_buylist_price || 0, max_buylist_price || buylist)
  end

  private

  def buylist_range_in_order
    return unless min_buylist_price && max_buylist_price && min_buylist_price > max_buylist_price

    errors.add(:max_buylist_price, 'must be at least the minimum buylist price')
  end

  # A band going up to $1 comes back down to under it, and one going down to $1 comes back up over it
  def from_price_before_threshold
    return unless from_price && threshold_price
    return if reach_move == 'up' ? from_price < threshold_price : from_price > threshold_price

    errors.add(:from_price, "must be #{reach_move == 'up' ? 'under' : 'over'} the alert price")
  end
end
