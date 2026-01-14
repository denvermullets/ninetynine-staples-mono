module Collections
  class UpdateTotals < Service
    def initialize(collection:)
      @collection = collection
    end

    def call
      owned_cards = @collection.collection_magic_cards.finalized.owned
      @collection.update!(
        total_quantity: owned_cards.sum(:quantity),
        total_foil_quantity: owned_cards.sum(:foil_quantity),
        total_value: calculate_total_value(owned_cards),
        total_proxy_quantity: owned_cards.sum(:proxy_quantity),
        total_proxy_foil_quantity: owned_cards.sum(:proxy_foil_quantity),
        proxy_total_value: calculate_proxy_value(owned_cards)
      )
    end

    private

    def calculate_total_value(cards)
      cards.sum do |c|
        (c.quantity * c.magic_card.normal_price.to_f) +
          (c.foil_quantity * c.magic_card.foil_price.to_f)
      end
    end

    def calculate_proxy_value(cards)
      cards.sum do |c|
        (c.proxy_quantity.to_i * c.magic_card.normal_price.to_f) +
          (c.proxy_foil_quantity.to_i * c.magic_card.foil_price.to_f)
      end
    end
  end
end
