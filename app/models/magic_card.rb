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

  has_many :magic_card_colors
  has_many :colors, through: :magic_card_colors

  has_many :magic_card_color_idents
  has_many :colors, through: :magic_card_color_idents

  has_many :magic_card_rulings
  has_many :rulings, through: :magic_card_rulings

  has_many :magic_card_keywords
  has_many :keywords, through: :magic_card_keywords

  def price_change
    # determine how much value has changed
    price_changes = {}

    %w[foil normal].each do |type|
      prices = price_history[type]&.last(2) || []
      next unless prices.size == 2

      old_price = prices.first.values.first
      new_price = prices.last.values.first
      price_changes[type] = {
        old_price: old_price,
        new_price: new_price,
        change: (new_price - old_price).round(2)
      }
    end

    price_changes
  end
end
