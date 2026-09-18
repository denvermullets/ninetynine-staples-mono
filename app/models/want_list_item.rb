# A card a user is looking for.
#
# `magic_card_id` always points at a printing, but when `any_printing` is set it is only the printing
# the user happened to pick: any card sharing its oracle id satisfies the want. `scryfall_oracle_id` is
# copied from that printing so matching is a single-table lookup. A printing without an oracle id can
# only be matched exactly, whatever `any_printing` says.
#
# A double-faced card is one card here: a want always points at the front face, and a back face
# passed to `matching` is read as its front, so "this exact printing" means the same thing from
# either side.
class WantListItem < ApplicationRecord
  FOIL_PREFERENCES = %w[any foil non_foil].freeze

  belongs_to :user
  belongs_to :magic_card

  before_validation :anchor_to_front_face, if: :will_save_change_to_magic_card_id?

  validates :foil_preference, inclusion: { in: FOIL_PREFERENCES }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :magic_card_id, uniqueness: { scope: :user_id }
  validates :scryfall_oracle_id, uniqueness: { scope: :user_id, conditions: -> { any_printing } },
                                 allow_nil: true, if: :any_printing?

  scope :any_printing, -> { where(any_printing: true) }
  scope :specific_printing, -> { where(any_printing: false) }
  scope :for_oracle, ->(oracle_id) { where(scryfall_oracle_id: oracle_id) }
  scope :for_printing, ->(magic_card_id) { where(magic_card_id: magic_card_id) }

  # Rows that `magic_card` would satisfy: the exact printing always matches, and any-printing rows
  # match on oracle id when the card has one.
  def self.matching(magic_card)
    magic_card = magic_card.front_face
    exact = for_printing(magic_card.id)
    return exact if magic_card.scryfall_oracle_id.blank?

    exact.or(any_printing.for_oracle(magic_card.scryfall_oracle_id))
  end

  private

  def anchor_to_front_face
    self.magic_card = magic_card.front_face if magic_card
    self.scryfall_oracle_id = magic_card&.scryfall_oracle_id
  end
end
