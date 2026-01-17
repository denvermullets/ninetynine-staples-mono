module Collections
  class AggregateQuantities < Service
    def initialize(magic_cards:, user:)
      @magic_cards = magic_cards
      @user = user
    end

    def call
      return {} if @magic_cards.empty? || @user.nil?

      magic_card_ids = @magic_cards.map(&:id)

      CollectionMagicCard
        .joins(:collection)
        .where(collections: { user_id: @user.id })
        .where(magic_card_id: magic_card_ids)
        .group(:magic_card_id)
        .pluck(:magic_card_id, Arel.sql('SUM(quantity)'), Arel.sql('SUM(foil_quantity)'))
        .each_with_object({}) do |(card_id, qty, foil_qty), hash|
          hash[card_id] = {
            total_quantity: qty.to_i,
            total_foil_quantity: foil_qty.to_i
          }
        end
    end
  end
end
