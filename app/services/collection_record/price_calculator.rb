# Shared price calculation logic for collection services
module CollectionRecord
  module PriceCalculator
    private

    # prices are nullable - to_d treats nil as 0 and keeps the math in BigDecimal
    def calculate_price(quantity, foil_quantity)
      (quantity * @magic_card.normal_price.to_d) + (foil_quantity * @magic_card.foil_price.to_d)
    end

    def calculate_price_change(quantity_change, foil_quantity_change)
      (quantity_change * @magic_card.normal_price.to_d) + (foil_quantity_change * @magic_card.foil_price.to_d)
    end

    def calculate_real_price(collection_card)
      (collection_card.quantity * @magic_card.normal_price.to_d) +
        (collection_card.foil_quantity * @magic_card.foil_price.to_d)
    end

    def calculate_proxy_price(collection_card)
      (collection_card.proxy_quantity * @magic_card.proxy_normal_price) +
        (collection_card.proxy_foil_quantity * @magic_card.proxy_foil_price)
    end
  end
end
