# frozen_string_literal: true

module CardScanner
  class OwnershipLoader < Service
    def initialize(card_ids:, user:)
      @card_ids = card_ids
      @user = user
    end

    def call
      return {} unless @user

      build_ownership_hash(fetch_records)
    end

    private

    def fetch_records
      CollectionMagicCard.joins(:collection)
                         .where(magic_card_id: @card_ids)
                         .where(collections: { user_id: @user.id })
                         .merge(non_deck_collections)
                         .group(:magic_card_id)
                         .select(*quantity_columns)
    end

    def non_deck_collections
      Collection.where.not('collection_type = ? OR collection_type LIKE ?', 'deck', '%_deck')
    end

    def quantity_columns
      [
        :magic_card_id,
        'SUM(quantity) as quantity',
        'SUM(foil_quantity) as foil_quantity',
        'SUM(proxy_quantity) as proxy_quantity',
        'SUM(proxy_foil_quantity) as proxy_foil_quantity'
      ]
    end

    def build_ownership_hash(records)
      records.index_by(&:magic_card_id).transform_values do |r|
        {
          quantity: r.quantity.to_i,
          foil_quantity: r.foil_quantity.to_i,
          proxy_quantity: r.proxy_quantity.to_i,
          proxy_foil_quantity: r.proxy_foil_quantity.to_i
        }
      end
    end
  end
end
