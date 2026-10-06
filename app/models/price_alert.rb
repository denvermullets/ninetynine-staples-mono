# Something a user wants to hear about when a price moves. Only the rule lives here; the
# evaluation job decides when it fires and delivers it through Notifications::Deliver.
#
# Four shapes share the table:
#
# - threshold: "tell me when this card goes above / below $X". It watches one printing
#   (magic_card_id) or any printing of a card (scryfall_oracle_id), so it covers owned cards and
#   want-list items alike. It re-arms rather than firing once: `last_side` records which side of
#   the threshold the price was on, and the job fires only when the price lands on the other side.
#   `last_side` is set from the current price when the alert is saved, so a card already past $X
#   does not fire the moment the alert is made. While `last_side` is the alert's own direction it
#   is disarmed, and only re-arms once the price comes back past $X by REARM_MARGIN, so a card
#   hovering around the line does not notify every day.
# - movement rule (no card): "anything I own moves ±$5 / ±15% daily or weekly". The fields are the
#   movers table's filters (CollectionStats::MoversTable), so a rule is a saved filter, optionally
#   narrowed to one of the user's collections.
# - movement override (with a card): the same test for one printing, measured on the card's unit
#   price rather than a holding, since it can watch a want-list card nobody owns. While one is
#   active, collection-wide rules for that window skip the card. At most one per card and window.
# - band (no card): "anything I own that goes up to $1 or more, or back down to $0.90 or less". A
#   threshold across every card in a collection, or all of them, with `from_price` as its second
#   line in place of REARM_MARGIN; see PriceAlertBands for which moves each direction lists. The
#   band itself keeps no side; each card's lives in a PriceBandCard, and the crossings nobody has
#   handled yet are the band's worklist. See PriceAlerts::SyncBand.
#
# Movement rules and bands both take a Card Kingdom buylist range (min/max_buylist_price), which
# narrows the cards they count the way the movers table's buylist filter does.
class PriceAlert < ApplicationRecord
  KINDS = %w[threshold movement band].freeze
  FINISHES = %w[normal foil any].freeze
  PRINTING_FINISHES = %w[normal foil].freeze
  THRESHOLD_DIRECTIONS = %w[above below].freeze
  MOVEMENT_DIRECTIONS = %w[up down both].freeze
  WINDOWS = %w[daily weekly].freeze
  SIDES = %w[above below].freeze
  # how far past the threshold, as a fraction of it, the price has to come back to re-arm an alert
  REARM_MARGIN = BigDecimal('0.05')
  PRICE_COLUMNS = { 'normal' => %i[normal_price], 'foil' => %i[foil_price],
                    'any' => %i[normal_price foil_price] }.freeze

  # WantListItem::FOIL_PREFERENCES in this table's finish vocabulary
  FINISH_FOR_FOIL_PREFERENCE = { 'any' => 'any', 'foil' => 'foil', 'non_foil' => 'normal' }.freeze

  include PriceAlertBands

  belongs_to :user
  belongs_to :magic_card, optional: true
  belongs_to :collection, optional: true

  before_save :set_last_side, if: :threshold_target_changed?

  validates :kind, inclusion: { in: KINDS }
  validates :finish, inclusion: { in: FINISHES }
  validates :last_side, inclusion: { in: SIDES }, allow_nil: true
  validates :threshold_price, :min_delta_amount, :min_delta_percent, :min_price, :from_price,
            :min_buylist_price, :max_buylist_price, numericality: { greater_than: 0 }, allow_nil: true

  with_options if: :threshold? do
    validates :threshold_price, presence: true
    validates :direction, inclusion: { in: THRESHOLD_DIRECTIONS }
    validates :collection_id, :from_price, :min_buylist_price, :max_buylist_price, absence: true
    validate :watches_one_target
  end

  with_options if: :movement? do
    validates :window, inclusion: { in: WINDOWS }
    validates :direction, inclusion: { in: MOVEMENT_DIRECTIONS }
    validates :threshold_price, :scryfall_oracle_id, :from_price, absence: true
    validate :needs_a_minimum_move
  end

  with_options if: -> { movement? && magic_card_id } do
    validates :collection_id, absence: true
    validate :one_override_per_window
  end

  validate :collection_belongs_to_user, if: :collection

  scope :active, -> { where(active: true) }
  scope :thresholds, -> { where(kind: 'threshold') }
  scope :movements, -> { where(kind: 'movement') }
  scope :movement_rules, -> { movements.where(magic_card_id: nil, scryfall_oracle_id: nil) }
  scope :card_overrides, -> { movements.where.not(magic_card_id: nil) }
  # rules counting exactly these .movement_rule_attributes
  scope :matching_rule, ->(attributes) { movement_rules.where(attributes) }

  # An unsaved threshold alert watching what the want item asks for: any printing when the want
  # matches by oracle id, otherwise its exact printing, in the finish it prefers. An exact printing
  # needs a concrete finish, so `any` falls back to non-foil there.
  def self.threshold_for_want(want_list_item, threshold_price:, direction:)
    finish = FINISH_FOR_FOIL_PREFERENCE.fetch(want_list_item.foil_preference)
    target = if want_list_item.matches_by_oracle?
               { scryfall_oracle_id: want_list_item.scryfall_oracle_id }
             else
               { magic_card: want_list_item.magic_card, finish: finish == 'any' ? 'normal' : finish }
             end

    new(user: want_list_item.user, kind: 'threshold', finish: finish, threshold_price: threshold_price,
        direction: direction, **target)
  end

  def threshold?
    kind == 'threshold'
  end

  def movement?
    kind == 'movement'
  end

  def movement_rule?
    movement? && magic_card_id.nil?
  end

  # The cheapest priced printing of each card, per finish, plus a name to call the card by, keyed by
  # oracle id. One query however many cards, so the evaluation job can price every oracle alert at
  # once. Front faces only: each face of a double-faced printing is its own row but one card. A
  # price of 0 means unpriced, never free, so it never wins the MIN.
  def self.cheapest_printings(oracle_ids)
    MagicCard.where(scryfall_oracle_id: oracle_ids, card_side: [nil, 'a'])
             .group(:scryfall_oracle_id)
             .pluck(:scryfall_oracle_id,
                    Arel.sql('MIN(CASE WHEN magic_cards.normal_price > 0 THEN magic_cards.normal_price END)'),
                    Arel.sql('MIN(CASE WHEN magic_cards.foil_price > 0 THEN magic_cards.foil_price END)'),
                    Arel.sql('MIN(magic_cards.name)'))
             .to_h { |oracle_id, normal, foil, name| [oracle_id, { normal_price: normal, foil_price: foil, name: }] }
  end

  # The price this alert watches right now, or nil when there is none to watch. A printing reads its
  # own finish's price; an oracle alert reads the cheapest printing of the card in that finish, and
  # `any` the cheapest of either finish. A price of 0 means unpriced, never free, so it is skipped.
  #
  # `cheapest` is .cheapest_printings already run for a batch of alerts; without it an oracle alert
  # looks its own card up.
  def current_price(cheapest: nil)
    if magic_card
      price_for(magic_card)
    elsif scryfall_oracle_id.present?
      cheapest ||= self.class.cheapest_printings([scryfall_oracle_id])
      price_for(cheapest.fetch(scryfall_oracle_id, {}))
    end
  end

  # A movement rule as CollectionStats::MoversTable filters, which are also the movers page's query
  # string, so a notification can link to exactly what it counted. Amounts go out as plain decimals:
  # a BigDecimal's own to_s is scientific notation.
  def movers_filters
    { window: window, direction: direction, finish: finish == 'any' ? 'both' : finish,
      min_delta: min_delta_amount&.to_s('F'), min_percent: min_delta_percent&.to_s('F'),
      min_price: min_price&.to_s('F'), min_buylist: min_buylist_price&.to_s('F'),
      max_buylist: max_buylist_price&.to_s('F') }.compact
  end

  # The other way round from #movers_filters: the movement rule a set of CollectionStats::MoversTable
  # filters saves as, so the page's "alert me" button and the duplicate check agree on what a rule
  # is. Sort and page are not part of a rule. Amounts are rounded to the columns' two places, so an
  # existing rule is found by the values it was actually stored with.
  def self.movement_rule_attributes(filters, collection_id: nil)
    { collection_id: collection_id, window: filters[:window], direction: filters[:direction],
      finish: filters[:finish] == 'both' ? 'any' : filters[:finish],
      min_delta_amount: cents(filters[:min_delta]), min_delta_percent: cents(filters[:min_percent]),
      min_price: cents(filters[:min_price]), min_buylist_price: cents(filters[:min_buylist]),
      max_buylist_price: cents(filters[:max_buylist]) }
  end

  # an amount that rounds to nothing is no minimum at all, the same as the movers table reads it
  def self.cents(value)
    rounded = value&.to_d&.round(2)
    rounded if rounded&.positive?
  end
  private_class_method :cents

  # Which side of the threshold `price` sits on. Landing exactly on $X counts as reaching it.
  def side_for(price)
    return nil if price.nil? || threshold_price.nil?

    price >= threshold_price ? 'above' : 'below'
  end

  # Whether the alert has gone off (or was made with the price already past $X) and is waiting for
  # the price to come back past #rearm_price before it can fire again.
  def disarmed?
    threshold? && last_side.present? && last_side == direction
  end

  # The price a disarmed alert has to come back past to re-arm: under $X less the margin for an
  # "above" alert, over $X plus the margin for a "below" one.
  def rearm_price
    return nil unless threshold_price

    margin = threshold_price * REARM_MARGIN
    (direction == 'above' ? threshold_price - margin : threshold_price + margin).round(2)
  end

  # Whether `price` is far enough back from the line to re-arm. Coming back to exactly #rearm_price
  # counts.
  def rearms_at?(price)
    return false if price.nil? || rearm_price.nil?

    direction == 'above' ? price <= rearm_price : price >= rearm_price
  end

  private

  # a printing, or one of .cheapest_printings' rows
  def price_for(prices)
    PRICE_COLUMNS.fetch(finish).filter_map { |column| positive(prices[column]) }.min
  end

  def positive(price)
    price if price&.positive?
  end

  def threshold_target_changed?
    threshold? && (new_record? || will_save_change_to_threshold_price? || will_save_change_to_finish? ||
                   will_save_change_to_magic_card_id? || will_save_change_to_scryfall_oracle_id?)
  end

  def set_last_side
    self.last_side = side_for(current_price)
  end

  def watches_one_target
    if magic_card_id.present? == scryfall_oracle_id.present?
      errors.add(:base, 'must watch exactly one of a printing or a card')
    elsif magic_card_id && PRINTING_FINISHES.exclude?(finish)
      errors.add(:finish, 'must be normal or foil for a single printing')
    end
  end

  def needs_a_minimum_move
    return if min_delta_amount || min_delta_percent

    errors.add(:base, 'needs a minimum move in dollars or percent')
  end

  def one_override_per_window
    duplicate = PriceAlert.card_overrides.where(user_id: user_id, magic_card_id: magic_card_id, window: window)
                          .where.not(id: id).exists?
    errors.add(:magic_card_id, :taken) if duplicate
  end

  def collection_belongs_to_user
    errors.add(:collection, 'must be one of your collections') unless collection.user_id == user_id
  end
end
