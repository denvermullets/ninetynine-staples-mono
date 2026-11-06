# The copies a counter-offer could give instead of the one a row holds: every other row of the same
# card the user could offer, whichever printing it is. A different collection's copy of the same
# printing counts too - it is the same swap to whoever is giving it up.
#
# The same card across printings is the one MagicCard#other_printing_locations matches on, the oracle
# id, but the rows are held to User#offerable_cards. Trades::Propose would refuse anything else, so a
# copy in a private collection is not an option here even though the trade page's card panel lists it.
#
# Listed rows are included, unlike Trades::UnlistedRows: a swap is asking "what else do I have of
# this", and the builder finds a chosen row that is already on the page rather than drawing it twice.
module Trades
  class OtherPrintings < Service
    LIMIT = 25

    def initialize(user:, row:, except_trade: nil)
      @user = user
      @row = row
      @except_trade = except_trade
    end

    def call
      oracle_id = @row.magic_card.scryfall_oracle_id
      return [] if oracle_id.blank?

      AvailableRows.call(user: @user, except_trade: @except_trade, scope: scope(oracle_id))
    end

    private

    def scope(oracle_id)
      @user.offerable_cards.joins(:magic_card)
           .where(magic_cards: { scryfall_oracle_id: oracle_id, card_side: [nil, 'a'] })
           .where.not(id: @row.id)
           .limit(LIMIT)
    end
  end
end
