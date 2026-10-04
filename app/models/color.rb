class Color < ApplicationRecord
  # colors.name holds MTGJSON's single letters, not display names -
  # CardIngestion::AttributeCreator writes the raw colors and colorIdentity arrays straight through.
  NAMES = { 'W' => 'White', 'U' => 'Blue', 'B' => 'Black', 'R' => 'Red', 'G' => 'Green' }.freeze

  validates :name, uniqueness: { case_sensitive: false }

  has_many :magic_card_colors
  has_many :magic_cards, through: :magic_card_colors

  has_many :magic_card_color_idents
  has_many :identity_magic_cards, through: :magic_card_color_idents, source: :magic_card

  def display_name
    NAMES.fetch(name, name)
  end
end
