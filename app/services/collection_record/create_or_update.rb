# this service will create or update a collection record and update the collection totals
module CollectionRecord
  class CreateOrUpdate < Service
    def initialize(collection_magic_card:, params:)
      @card_params = params
      @quantity = params[:quantity]
      @foil_quantity = params[:foil_quantity]
      @collection = Collection.find(params[:collection_id])
      @magic_card = MagicCard.find(params[:magic_card_id])
      @collection_magic_card = collection_magic_card
    end

    def call
      if @collection_magic_card.nil?
        create_record
      else
        update_existing_collection_magic_card

        if nil_quantity
          deleted_card = @collection_magic_card.magic_card.name
          @collection_magic_card.delete

          return { action: :delete, name: deleted_card }
        end
      end

      { action: :success, name: @collection_magic_card.magic_card.name }
    end

    private

    def create_record
      @collection_magic_card = CollectionMagicCard.create(@card_params)
      # add new cards to collection total value
      current_total = @collection.total_value || 0
      @collection.update(total_value: current_total + determine_value)
    end

    def update_existing_collection_magic_card
      old_value = determine_value
      update_collection_quantity_totals
      @collection_magic_card.update(@card_params)
      new_value = determine_value

      collection_value = @collection.total_value || 0

      if old_value < new_value
        # quantity change has gained value
        @collection.update(total_value: collection_value + (new_value - old_value))
      else
        # quantity change has lowered value
        difference = calculate_value_change(old_value, new_value)
        @collection.update(total_value: force_min_value(collection_value, difference))
      end
    end

    def determine_value
      # just multiplies quantity x price and adds together
      normal_price = (@collection_magic_card.quantity || 0) * (@magic_card.normal_price || 0)
      foil_price = (@collection_magic_card.foil_quantity || 0) * (@magic_card.foil_price || 0)
      normal_price + foil_price
    end

    def update_collection_quantity_totals
      foil_quantity = @card_params[:foil_quantity].to_i - @collection_magic_card.foil_quantity
      quantity = @card_params[:quantity].to_i - @collection_magic_card.quantity
      new_foil_quantity = @collection.total_foil_quantity + foil_quantity.to_i
      new_quantity = @collection.total_quantity + quantity.to_i

      @collection.update(total_foil_quantity: new_foil_quantity, total_quantity: new_quantity)
    end

    def calculate_value_change(old_value, new_value)
      if new_value.positive?
        old_value - new_value
      else
        old_value
      end
    end

    def force_min_value(collection_value, difference)
      # just in case it goes negative, we don't want collections to be negative value
      new_total = collection_value - difference
      [new_total, 0].max
    end

    def nil_quantity
      quantity = @collection_magic_card.quantity
      foil_quantity = @collection_magic_card.foil_quantity

      (quantity.nil? || quantity.zero?) && (foil_quantity.nil? || foil_quantity.zero?)
    end
  end
end
