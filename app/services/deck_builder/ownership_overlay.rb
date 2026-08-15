module DeckBuilder
  # "Which of these cards do I already have a free copy of, and where is it?"
  #
  # Free means owned but not already promised to another deck: StagedQuantities subtracts copies staged
  # out of the source collection. Rows in the deck being built are excluded, since a card you already put
  # in this deck is not a copy you can add to it.
  #
  # Shared by ReplacementFinder and CommanderSynergy so both render the same "2 in Binder (Foil)" chips
  # off the same numbers.
  class OwnershipOverlay < Service
    def initialize(user:, oracle_ids:, exclude_collection_id: nil)
      @user = user
      @oracle_ids = oracle_ids
      @exclude_collection_id = exclude_collection_id
    end

    # -> { oracle_id => [{ collection_id:, collection_name:, magic_card_id:, magic_card:, card_type:,
    #                      type_label:, available: }] }
    def call
      return {} unless @user

      rows = owned_rows.to_a
      return {} if rows.empty?

      available = StagedQuantities.calculate_available_batch(sources: rows)

      rows.group_by { |row| row.magic_card.scryfall_oracle_id }.transform_values do |copies|
        copies.flat_map { |copy| entries_for(copy, available[copy.id]) }
      end
    end

    private

    def owned_rows
      scope = CollectionMagicCard
              .joins(:collection, :magic_card)
              .includes(:collection, magic_card: :boxset)
              .where(collections: { user_id: @user.id })
              .where(magic_cards: { scryfall_oracle_id: @oracle_ids })
              .where(staged: false, needed: false)

      @exclude_collection_id ? scope.where.not(collection_id: @exclude_collection_id) : scope
    end

    def entries_for(collection_card, available)
      StagedQuantities::QUANTITY_TYPES.filter_map do |type|
        next unless available[type].positive?

        { collection_id: collection_card.collection_id,
          collection_name: collection_card.collection.name,
          magic_card_id: collection_card.magic_card_id,
          magic_card: collection_card.magic_card,
          card_type: type,
          type_label: StagedQuantities::TYPE_LABELS[type],
          available: available[type] }
      end
    end
  end
end
