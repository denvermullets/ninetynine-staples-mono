# Service to update collection aggregate totals
module CollectionRecord
  class UpdateTotals < Service
    def initialize(collection:, changes:)
      @collection = collection
      @quantity_change = changes[:quantity] || 0
      @foil_quantity_change = changes[:foil_quantity] || 0
      @proxy_quantity_change = changes[:proxy_quantity] || 0
      @proxy_foil_quantity_change = changes[:proxy_foil_quantity] || 0
      @real_price_change = changes[:real_price] || 0
      @proxy_price_change = changes[:proxy_price] || 0
    end

    def call
      @collection.increment!(:total_quantity, @quantity_change)
      @collection.increment!(:total_foil_quantity, @foil_quantity_change)
      @collection.increment!(:total_proxy_quantity, @proxy_quantity_change)
      @collection.increment!(:total_proxy_foil_quantity, @proxy_foil_quantity_change)
      @collection.increment!(:total_value, @real_price_change)
      @collection.increment!(:proxy_total_value, @proxy_price_change)
      @collection.touch
    end
  end
end
