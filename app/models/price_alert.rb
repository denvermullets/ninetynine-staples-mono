# Something a user wants to hear about when a price moves. Only the rule lives here; the
# evaluation job decides when it fires and delivers it through Notifications::Deliver.
#
# Three shapes share the table:
#
# - threshold: "tell me when this card goes above / below $X". It watches one printing
#   (magic_card_id) or any printing of a card (scryfall_oracle_id), so it covers owned cards and
#   want-list items alike. It re-arms rather than firing once: `last_side` records which side of
#   the threshold the price was on, and the job fires only when the price lands on the other side.
#   `last_side` is set from the current price when the alert is saved, so a card already past $X
#   does not fire the moment the alert is made.
# - movement rule (no card): "anything I own moves ±$5 / ±15% daily or weekly". The fields are the
#   movers table's filters (CollectionStats::MoversTable), so a rule is a saved filter, optionally
#   narrowed to one of the user's collections.
# - movement override (with a card): the same test for one printing, measured on the card's unit
#   price rather than a holding, since it can watch a want-list card nobody owns. While one is
#   active, collection-wide rules for that window skip the card. At most one per card and window.
class PriceAlert < ApplicationRecord
  KINDS = %w[threshold movement].freeze
  FINISHES = %w[normal foil any].freeze
  PRINTING_FINISHES = %w[normal foil].freeze
  THRESHOLD_DIRECTIONS = %w[above below].freeze
  MOVEMENT_DIRECTIONS = %w[up down both].freeze
  WINDOWS = %w[daily weekly].freeze
  SIDES = %w[above below].freeze
  PRICE_COLUMNS = { 'normal' => %i[normal_price], 'foil' => %i[foil_price],
                    'any' => %i[normal_price foil_price] }.freeze

  # WantListItem::FOIL_PREFERENCES in this table's finish vocabulary
  FINISH_FOR_FOIL_PREFERENCE = { 'any' => 'any', 'foil' => 'foil', 'non_foil' => 'normal' }.freeze

  belongs_to :user
  belongs_to :magic_card, optional: true
  belongs_to :collection, optional: true

  before_save :set_last_side, if: :threshold_target_changed?

  validates :kind, inclusion: { in: KINDS }
  validates :finish, inclusion: { in: FINISHES }
  validates :last_side, inclusion: { in: SIDES }, allow_nil: true
  validates :threshold_price, :min_delta_amount, :min_delta_percent, :min_price,
            numericality: { greater_than: 0 }, allow_nil: true

  with_options if: :threshold? do
    validates :threshold_price, presence: true
    validates :direction, inclusion: { in: THRESHOLD_DIRECTIONS }
    validates :collection_id, absence: true
    validate :watches_one_target
  end

  with_options if: :movement? do
    validates :window, inclusion: { in: WINDOWS }
    validates :direction, inclusion: { in: MOVEMENT_DIRECTIONS }
    validates :threshold_price, :scryfall_oracle_id, absence: true
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

  # The price this alert watches right now, or nil when there is none to watch. A printing reads its
  # own finish's price; an oracle alert reads the cheapest printing of the card in that finish, and
  # `any` the cheapest of either finish. A price of 0 means unpriced, never free, so it is skipped.
  def current_price
    if magic_card
      price_for(magic_card)
    elsif scryfall_oracle_id.present?
      cheapest_printing_price
    end
  end

  # Which side of the threshold `price` sits on. Landing exactly on $X counts as reaching it.
  def side_for(price)
    return nil if price.nil? || threshold_price.nil?

    price >= threshold_price ? 'above' : 'below'
  end

  private

  def price_for(card)
    PRICE_COLUMNS.fetch(finish).filter_map { |column| positive(card.public_send(column)) }.min
  end

  def positive(price)
    price if price&.positive?
  end

  # front faces only: each face of a double-faced printing is its own row but one card
  def cheapest_printing_price
    printings = MagicCard.where(scryfall_oracle_id: scryfall_oracle_id, card_side: [nil, 'a'])
    columns = PRICE_COLUMNS.fetch(finish)

    columns.filter_map { |column| printings.where(MagicCard.arel_table[column].gt(0)).minimum(column) }.min
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
