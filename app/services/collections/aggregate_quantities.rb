module Collections
  class AggregateQuantities < Service
    def initialize(magic_card_ids:, user:, collection_id: nil)
      @magic_card_ids = magic_card_ids
      @user = user
      @collection_id = collection_id
    end

    def call
      return {} if @magic_card_ids.blank? || @user.nil?

      scoped_rows.each_with_object({}) do |(card_id, qty, foil_qty), hash|
        hash[card_id] = {
          total_quantity: qty.to_i,
          total_foil_quantity: foil_qty.to_i
        }
      end
    end

    private

    # narrowed to the selected collection when there is one, so the visual badges match the
    # quantity column the table renders - that column comes from Search::Collection's SUM, which
    # is already collection-scoped. Without a collection_id (the all-collections view) a card can
    # live in several collections, so the totals stay summed across all of them.
    def scoped_rows
      scope = CollectionMagicCard.joins(:collection).where(collections: { user_id: @user.id })
      scope = scope.where(collections: { id: @collection_id }) if @collection_id.present?

      scope
        .where(magic_card_id: @magic_card_ids)
        .group(:magic_card_id)
        .pluck(:magic_card_id, Arel.sql('SUM(quantity)'), Arel.sql('SUM(foil_quantity)'))
    end
  end
end
