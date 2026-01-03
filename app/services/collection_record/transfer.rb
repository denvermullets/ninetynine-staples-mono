# this service transfers cards from one collection to another
module CollectionRecord
  class Transfer < Service
    def initialize(params:)
      @magic_card = MagicCard.find(params[:magic_card_id])
      @from_collection = Collection.find(params[:from_collection_id])
      @to_collection = Collection.find(params[:to_collection_id])
      @quantity = [params[:quantity].to_i, 0].max
      @foil_quantity = [params[:foil_quantity].to_i, 0].max
      @proxy_quantity = [params[:proxy_quantity].to_i, 0].max
      @proxy_foil_quantity = [params[:proxy_foil_quantity].to_i, 0].max
    end

    def call
      return { success: false, error: 'No cards to transfer' } if nothing_to_transfer?

      ActiveRecord::Base.transaction do
        from_card = find_source_card
        return { success: false, error: 'Card not found in source collection' } unless from_card
        return { success: false, error: 'Not enough cards to transfer' } unless sufficient_quantity?(from_card)

        update_source_collection(from_card)
        update_destination_collection(from_card.card_uuid)

        success_response
      end
    rescue ActiveRecord::RecordNotFound => e
      { success: false, error: "Error: #{e.message}" }
    rescue StandardError => e
      { success: false, error: "Transfer failed: #{e.message}" }
    end

    private

    def nothing_to_transfer?
      @quantity.zero? && @foil_quantity.zero? && @proxy_quantity.zero? && @proxy_foil_quantity.zero?
    end

    def find_source_card
      CollectionMagicCard.find_by(collection: @from_collection, magic_card: @magic_card)
    end

    def sufficient_quantity?(from_card)
      @quantity <= from_card.quantity &&
        @foil_quantity <= from_card.foil_quantity &&
        @proxy_quantity <= from_card.proxy_quantity &&
        @proxy_foil_quantity <= from_card.proxy_foil_quantity
    end

    def update_source_collection(from_card)
      new_quantity = from_card.quantity - @quantity
      new_foil_quantity = from_card.foil_quantity - @foil_quantity
      new_proxy_quantity = from_card.proxy_quantity - @proxy_quantity
      new_proxy_foil_quantity = from_card.proxy_foil_quantity - @proxy_foil_quantity

      if new_quantity.zero? && new_foil_quantity.zero? && new_proxy_quantity.zero? && new_proxy_foil_quantity.zero?
        remove_from_source(from_card)
      else
        decrease_source_quantity(from_card, new_quantity, new_foil_quantity, new_proxy_quantity,
                                 new_proxy_foil_quantity)
      end
    end

    def remove_from_source(from_card)
      real_price_change = -calculate_price(from_card.quantity, from_card.foil_quantity)
      proxy_price_change = -calculate_price(from_card.proxy_quantity, from_card.proxy_foil_quantity)

      update_collection_totals(
        @from_collection,
        -from_card.quantity,
        -from_card.foil_quantity,
        -from_card.proxy_quantity,
        -from_card.proxy_foil_quantity,
        real_price_change,
        proxy_price_change
      )
      from_card.destroy!
    end

    def decrease_source_quantity(from_card, new_quantity, new_foil_quantity, new_proxy_quantity,
                                 new_proxy_foil_quantity)
      quantity_change = -@quantity
      foil_quantity_change = -@foil_quantity
      proxy_quantity_change = -@proxy_quantity
      proxy_foil_quantity_change = -@proxy_foil_quantity

      real_price_change = calculate_price_change(quantity_change, foil_quantity_change)
      proxy_price_change = calculate_price_change(proxy_quantity_change, proxy_foil_quantity_change)

      from_card.update!(
        quantity: new_quantity,
        foil_quantity: new_foil_quantity,
        proxy_quantity: new_proxy_quantity,
        proxy_foil_quantity: new_proxy_foil_quantity
      )

      update_collection_totals(
        @from_collection,
        quantity_change,
        foil_quantity_change,
        proxy_quantity_change,
        proxy_foil_quantity_change,
        real_price_change,
        proxy_price_change
      )
    end

    def update_destination_collection(card_uuid)
      to_card = CollectionMagicCard.find_or_initialize_by(
        collection: @to_collection,
        magic_card: @magic_card,
        card_uuid:
      )

      to_card.quantity = (to_card.quantity || 0) + @quantity
      to_card.foil_quantity = (to_card.foil_quantity || 0) + @foil_quantity
      to_card.proxy_quantity = (to_card.proxy_quantity || 0) + @proxy_quantity
      to_card.proxy_foil_quantity = (to_card.proxy_foil_quantity || 0) + @proxy_foil_quantity
      to_card.save!

      real_price_change = calculate_price_change(@quantity, @foil_quantity)
      proxy_price_change = calculate_price_change(@proxy_quantity, @proxy_foil_quantity)

      update_collection_totals(
        @to_collection,
        @quantity,
        @foil_quantity,
        @proxy_quantity,
        @proxy_foil_quantity,
        real_price_change,
        proxy_price_change
      )
    end

    def success_response
      {
        success: true,
        card_id: @magic_card.id,
        name: @magic_card.name,
        from_collection: @from_collection.name,
        to_collection: @to_collection.name,
        locals: reload_card_details
      }
    end

    def calculate_price(quantity, foil_quantity)
      (quantity * @magic_card.normal_price) + (foil_quantity * @magic_card.foil_price)
    end

    def calculate_price_change(quantity_change, foil_quantity_change)
      (quantity_change * @magic_card.normal_price) + (foil_quantity_change * @magic_card.foil_price)
    end

    def update_collection_totals(collection, quantity_change, foil_quantity_change, proxy_quantity_change,
                                 proxy_foil_quantity_change, real_price_change, proxy_price_change)
      collection.increment!(:total_quantity, quantity_change)
      collection.increment!(:total_foil_quantity, foil_quantity_change)
      collection.increment!(:total_proxy_quantity, proxy_quantity_change)
      collection.increment!(:total_proxy_foil_quantity, proxy_foil_quantity_change)
      collection.increment!(:total_value, real_price_change)
      collection.increment!(:proxy_total_value, proxy_price_change)
      collection.touch
    end

    def reload_card_details
      user = @from_collection.user
      collections = user.collections
      card_locations = @magic_card.collection_magic_cards.joins(:collection).where(collections: { user_id: user.id })
      editable = true

      { card: @magic_card, collections:, card_locations:, editable: }
    end
  end
end
