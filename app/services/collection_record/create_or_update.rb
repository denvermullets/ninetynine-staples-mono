# this service will create or update a collection record and update the collection totals
module CollectionRecord
  class CreateOrUpdate < Service
    include PriceCalculator

    def initialize(params:)
      @collection = Collection.find(params[:collection_id])
      @magic_card = MagicCard.find(params[:magic_card_id])
      @quantity = [params[:quantity].to_i, 0].max
      @foil_quantity = [params[:foil_quantity].to_i, 0].max
      @proxy_quantity = [params[:proxy_quantity].to_i, 0].max
      @proxy_foil_quantity = [params[:proxy_foil_quantity].to_i, 0].max
      @card_uuid = params[:card_uuid]
    end

    def call
      ActiveRecord::Base.transaction do
        collection_card = CollectionMagicCard.find_or_initialize_by(
          collection: @collection,
          magic_card: @magic_card,
          card_uuid: @card_uuid
        )

        if @quantity.zero? && @foil_quantity.zero? && @proxy_quantity.zero? && @proxy_foil_quantity.zero?
          delete_collection_card(collection_card)

          return { action: :delete, name: collection_card.magic_card.name }
        else
          update_collection_card(collection_card)

          return { action: :success, name: collection_card.magic_card.name }
        end
      end
    end

    private

    def delete_collection_card(collection_card)
      return unless collection_card.persisted?

      real_price = calculate_real_price(collection_card)
      proxy_price = calculate_proxy_price(collection_card)

      UpdateTotals.call(
        collection: @collection,
        changes: {
          quantity: -collection_card.quantity,
          foil_quantity: -collection_card.foil_quantity,
          proxy_quantity: -collection_card.proxy_quantity,
          proxy_foil_quantity: -collection_card.proxy_foil_quantity,
          real_price: -real_price,
          proxy_price: -proxy_price
        }
      )
      collection_card.destroy!
    end

    def update_collection_card(collection_card)
      quantity_change = @quantity - collection_card.quantity
      foil_quantity_change = @foil_quantity - collection_card.foil_quantity
      proxy_quantity_change = @proxy_quantity - collection_card.proxy_quantity
      proxy_foil_quantity_change = @proxy_foil_quantity - collection_card.proxy_foil_quantity

      real_price_change = calculate_price_change(quantity_change, foil_quantity_change)
      proxy_price_change = calculate_price_change(proxy_quantity_change, proxy_foil_quantity_change)

      update_card_quantities(collection_card)

      UpdateTotals.call(
        collection: @collection,
        changes: {
          quantity: quantity_change,
          foil_quantity: foil_quantity_change,
          proxy_quantity: proxy_quantity_change,
          proxy_foil_quantity: proxy_foil_quantity_change,
          real_price: real_price_change,
          proxy_price: proxy_price_change
        }
      )
    end

    def update_card_quantities(card)
      card.update!(
        quantity: @quantity,
        foil_quantity: @foil_quantity,
        proxy_quantity: @proxy_quantity,
        proxy_foil_quantity: @proxy_foil_quantity
      )
    end
  end
end
