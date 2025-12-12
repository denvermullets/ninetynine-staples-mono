# this service transfers cards from one collection to another
module CollectionRecord
  class Transfer < Service
    def initialize(params:)
      @magic_card = MagicCard.find(params[:magic_card_id])
      @from_collection = Collection.find(params[:from_collection_id])
      @to_collection = Collection.find(params[:to_collection_id])
      @quantity = [params[:quantity].to_i, 0].max
      @foil_quantity = [params[:foil_quantity].to_i, 0].max
    end

    def call
      # Validate that we have something to transfer
      return { success: false, error: 'No cards to transfer' } if @quantity.zero? && @foil_quantity.zero?

      ActiveRecord::Base.transaction do
        # Find the source collection_magic_card
        from_card = CollectionMagicCard.find_by(
          collection: @from_collection,
          magic_card: @magic_card
        )

        return { success: false, error: 'Card not found in source collection' } unless from_card

        # Validate we have enough cards to transfer
        if @quantity > from_card.quantity || @foil_quantity > from_card.foil_quantity
          return { success: false, error: 'Not enough cards to transfer' }
        end

        # Update the source collection
        new_quantity = from_card.quantity - @quantity
        new_foil_quantity = from_card.foil_quantity - @foil_quantity

        if new_quantity.zero? && new_foil_quantity.zero?
          # Delete the card from source collection
          price_change = -calculate_price(from_card.quantity, from_card.foil_quantity)
          update_collection_totals(@from_collection, -from_card.quantity, -from_card.foil_quantity, price_change)
          from_card.destroy!
        else
          # Update the source collection card
          quantity_change = -@quantity
          foil_quantity_change = -@foil_quantity
          price_change = calculate_price_change(quantity_change, foil_quantity_change)

          from_card.update!(
            quantity: new_quantity,
            foil_quantity: new_foil_quantity
          )

          update_collection_totals(@from_collection, quantity_change, foil_quantity_change, price_change)
        end

        # Update the destination collection
        to_card = CollectionMagicCard.find_or_initialize_by(
          collection: @to_collection,
          magic_card: @magic_card,
          card_uuid: from_card.card_uuid
        )

        quantity_change = @quantity
        foil_quantity_change = @foil_quantity
        price_change = calculate_price_change(quantity_change, foil_quantity_change)

        to_card.quantity = (to_card.quantity || 0) + @quantity
        to_card.foil_quantity = (to_card.foil_quantity || 0) + @foil_quantity
        to_card.save!

        update_collection_totals(@to_collection, quantity_change, foil_quantity_change, price_change)

        # Return success with data for reloading the view
        {
          success: true,
          card_id: @magic_card.id,
          name: @magic_card.name,
          from_collection: @from_collection.name,
          to_collection: @to_collection.name,
          locals: reload_card_details
        }
      end
    rescue ActiveRecord::RecordNotFound => e
      { success: false, error: "Error: #{e.message}" }
    rescue StandardError => e
      { success: false, error: "Transfer failed: #{e.message}" }
    end

    private

    def calculate_price(quantity, foil_quantity)
      (quantity * @magic_card.normal_price) + (foil_quantity * @magic_card.foil_price)
    end

    def calculate_price_change(quantity_change, foil_quantity_change)
      (quantity_change * @magic_card.normal_price) + (foil_quantity_change * @magic_card.foil_price)
    end

    def update_collection_totals(collection, quantity_change, foil_quantity_change, price_change)
      collection.increment!(:total_quantity, quantity_change)
      collection.increment!(:total_foil_quantity, foil_quantity_change)
      collection.increment!(:total_value, price_change)
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
