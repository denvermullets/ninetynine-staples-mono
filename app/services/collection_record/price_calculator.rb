# Shared price calculation logic for collection services
module CollectionRecord
  module PriceCalculator
    private

    def calculate_price(quantity, foil_quantity)
      (quantity * @magic_card.normal_price) + (foil_quantity * @magic_card.foil_price)
    end

    def calculate_price_change(quantity_change, foil_quantity_change)
      (quantity_change * @magic_card.normal_price) + (foil_quantity_change * @magic_card.foil_price)
    end

    def calculate_real_price(collection_card)
      (collection_card.quantity * @magic_card.normal_price) + (collection_card.foil_quantity * @magic_card.foil_price)
    end

    def calculate_proxy_price(collection_card)
      (collection_card.proxy_quantity * @magic_card.normal_price) +
        (collection_card.proxy_foil_quantity * @magic_card.foil_price)
    end
  end
end
