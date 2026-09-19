# sets how many regular / foil copies on one collection row are up for trade
#
# Counts are clamped to what the row actually owns rather than rejected - the owner is typing into a
# number box, and "trade 5 of my 3" means "trade all 3". Staged and needed rows aren't owned copies,
# so they can't be offered. Proxies are never tradeable, so there's no proxy count to set.
module CollectionRecord
  class UpdateTrade < Service
    def initialize(collection_magic_card:, trade_quantity:, trade_foil_quantity:)
      @card = collection_magic_card
      @trade_quantity = trade_quantity
      @trade_foil_quantity = trade_foil_quantity
    end

    def call
      return { success: false, error: 'Only owned copies can be marked for trade.' } if @card.staged? || @card.needed?

      @card.update!(
        trade_quantity: bounded(@trade_quantity, @card.quantity),
        trade_foil_quantity: bounded(@trade_foil_quantity, @card.foil_quantity)
      )

      { success: true, name: @card.magic_card.name }
    end

    private

    def bounded(value, owned)
      value.to_i.clamp(0, owned.to_i)
    end
  end
end
