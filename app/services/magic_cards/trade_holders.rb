# Which of the people the viewer follows have this card up for trade - the "Up for trade" section of
# the card details panel.
#
# Only followed users, because this runs for every card anyone opens: across the whole user base it
# is a table nobody can read and a query that grows with every signup. A logged-out visitor follows
# nobody and gets nothing. Everyone offering a card is WantList::Traders' job, which is paged and
# only reachable from a want.
#
# One row per user per printing, covering this printing and every other printing of the same oracle
# id, summed across the holder's public collections. It reads the same set a trade partner is shown
# on that user's trade list: users.trades_public, User#tradeable_cards, and the raw trade_quantity
# counts rather than what is left after their open trades - the list and this section should never
# disagree about what someone is offering.
#
# Following someone opens nothing up - their trade list still has to be public. The viewer cannot
# follow themselves, so their own copies never show; the card locations above this section have them.
#
# `value` is the asking value at today's TCG retail, each finish at its own price with the
# Trades::UnitPrice fallbacks, so it matches what the trade builder will total the copies at.
#
# Ordered with this exact printing first, then by value, so the rows most likely to be what the
# viewer came looking for sit at the top.
module MagicCards
  class TradeHolders < Service
    LIMIT = 50

    Holder = Data.define(:user, :printing, :quantity, :foil_quantity, :value) do
      def copies
        quantity + foil_quantity
      end
    end

    def initialize(card:, viewer: nil)
      @card = card
      @viewer = viewer
    end

    def call
      return [] if @viewer.nil? || @card.scryfall_oracle_id.blank?

      holders = grouped.map { |(user_id, card_id), counts| holder(user_id, card_id, *counts) }
      holders.sort_by { |row| [row.printing.id == @card.id ? 0 : 1, -row.value, row.user.username.downcase] }
             .first(LIMIT)
    end

    private

    # [[user_id, magic_card_id], [quantity, foil_quantity]] pairs
    def grouped
      @grouped ||= scope.group('collections.user_id', 'collection_magic_cards.magic_card_id')
                        .pluck('collections.user_id', 'collection_magic_cards.magic_card_id',
                               Arel.sql('SUM(collection_magic_cards.trade_quantity)'),
                               Arel.sql('SUM(collection_magic_cards.trade_foil_quantity)'))
                        .to_h { |user_id, card_id, quantity, foil| [[user_id, card_id], [quantity.to_i, foil.to_i]] }
    end

    def scope
      CollectionMagicCard.tradeable
                         .merge(Collection.visible_to_public)
                         .joins(:magic_card, collection: :user)
                         .where(users: { trades_public: true })
                         .where(collections: { user_id: @viewer.active_follows.select(:followed_id) })
                         .where(magic_cards: { scryfall_oracle_id: @card.scryfall_oracle_id,
                                               card_side: [nil, 'a'] })
    end

    def holder(user_id, card_id, quantity, foil_quantity)
      printing = printings[card_id]

      Holder.new(user: users[user_id], printing: printing, quantity: quantity, foil_quantity: foil_quantity,
                 value: Trades::UnitPrice.value(quantity: quantity, foil_quantity: foil_quantity,
                                                normal: printing.normal_price, foil: printing.foil_price))
    end

    def users
      @users ||= User.where(id: grouped.keys.map(&:first).uniq).index_by(&:id)
    end

    def printings
      @printings ||= MagicCard.includes(:boxset).where(id: grouped.keys.map(&:last).uniq).index_by(&:id)
    end
  end
end
