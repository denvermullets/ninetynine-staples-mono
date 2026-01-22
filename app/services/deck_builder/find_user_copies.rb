module DeckBuilder
  class FindUserCopies < Service
    def initialize(magic_card:, user:)
      @magic_card = magic_card
      @user = user
    end

    def call
      oracle_id = @magic_card.scryfall_oracle_id
      return [] if oracle_id.blank?

      printing_ids = MagicCard.where(scryfall_oracle_id: oracle_id).pluck(:id)

      CollectionMagicCard
        .joins(:collection, :magic_card)
        .includes(:collection, magic_card: :boxset)
        .where(collections: { user_id: @user.id })
        .where(magic_card_id: printing_ids, staged: false, needed: false)
        .order('collections.name')
    end
  end
end
