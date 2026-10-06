# The rarities a movement rule counts - the movers table's rarity filter, saved. Empty counts every
# card. See PriceAlert.movement_rule_attributes.
module PriceAlertRarities
  extend ActiveSupport::Concern

  class_methods do
    # A rarity pick in the movers table's order, so the same pick is the same array however it
    # arrived - a form's blank "none picked" field and all.
    def rarity_pick(values)
      CollectionStats::MoversTable::RARITIES & Array(values).map(&:to_s)
    end
  end

  def rarities=(values)
    super(self.class.rarity_pick(values))
  end
end
