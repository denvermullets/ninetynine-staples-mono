#
# Fetches commons and uncommons worth more than $0.80
# from boxsets where the user has cards
#
module MarketMovers
  class FetchValuableCommons < Service
    MINIMUM_PRICE = 0.80
    TARGET_RARITIES = %w[common uncommon].freeze

    def initialize(user:, rarity: nil)
      @user = user
      @rarity = rarity
    end

    def call
      return MagicCard.none unless @user

      # Get all boxsets where user has cards across all collections
      user_boxset_ids = @user.collections
                             .joins(magic_cards: :boxset)
                             .select('DISTINCT boxsets.id')
                             .map(&:id)

      return MagicCard.none if user_boxset_ids.empty?

      # Determine which rarities to query
      rarities = if @rarity.present? && TARGET_RARITIES.include?(@rarity)
                   [@rarity]
                 else
                   TARGET_RARITIES
                 end

      # Find valuable commons and uncommons from those boxsets
      MagicCard.where(boxset_id: user_boxset_ids)
               .where(rarity: rarities)
               .where('normal_price > ? OR foil_price > ?', MINIMUM_PRICE, MINIMUM_PRICE)
               .includes(:boxset)
               .order(normal_price: :desc, foil_price: :desc)
    end
  end
end
