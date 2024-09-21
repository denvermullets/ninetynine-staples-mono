class CollectionMagicCard < ApplicationRecord
  belongs_to :collection
  belongs_to :magic_card

  scope :by_set, ->(id, set) { includes(:magic_card).where(collection_id: id, magic_card: { boxset_id: set }) }
  scope :by_id, ->(id) { includes(:magic_card, magic_card: :boxset).where(collection_id: id) }
  scope :by_boxset, ->(id) { left_joins(:magic_card).where(magic_cards: { boxset_id: id }) }

  def max_price
    [ magic_card.normal_price || 0, magic_card.foil_price || 0 ].max
  end
end
