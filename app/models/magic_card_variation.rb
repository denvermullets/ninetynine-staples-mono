class MagicCardVariation < ApplicationRecord
  belongs_to :magic_card
  belongs_to :variation, class_name: 'MagicCard'
end
