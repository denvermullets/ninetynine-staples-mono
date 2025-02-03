# this service will create or update a collection record and update the collection totals
module CollectionRecord
  class CreateOrUpdate < Service
    def initialize(params:)
      @collection = Collection.find(params[:collection_id])
      @magic_card = MagicCard.find(params[:magic_card_id])
      @quantity = [params[:quantity].to_i, 0].max
      @foil_quantity = [params[:foil_quantity].to_i, 0].max
      @card_uuid = params[:card_uuid]
    end

    def call
      ActiveRecord::Base.transaction do
        collection_card = CollectionMagicCard.find_or_initialize_by(
          collection: @collection,
          magic_card: @magic_card,
          card_uuid: @card_uuid
        )

        if @quantity.zero? && @foil_quantity.zero?
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

      update_totals(-collection_card.quantity, -collection_card.foil_quantity, -calculate_price(collection_card))
      collection_card.destroy!
    end

    def update_collection_card(collection_card)
      quantity_change = @quantity - collection_card.quantity
      foil_quantity_change = @foil_quantity - collection_card.foil_quantity
      price_change = calculate_price_change(quantity_change, foil_quantity_change)

      collection_card.update!(
        quantity: @quantity,
        foil_quantity: @foil_quantity
      )

      update_totals(quantity_change, foil_quantity_change, price_change)
    end

    def calculate_price(collection_card)
      (collection_card.quantity * @magic_card.normal_price) + (collection_card.foil_quantity * @magic_card.foil_price)
    end

    def calculate_price_change(quantity_change, foil_quantity_change)
      (quantity_change * @magic_card.normal_price) + (foil_quantity_change * @magic_card.foil_price)
    end

    def update_totals(quantity_change, foil_quantity_change, price_change)
      @collection.increment!(:total_quantity, quantity_change)
      @collection.increment!(:total_foil_quantity, foil_quantity_change)
      @collection.increment!(:total_value, price_change)
      @collection.touch
    end
  end
end
