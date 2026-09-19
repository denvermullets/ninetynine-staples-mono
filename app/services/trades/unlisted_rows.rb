# The rest of a user's public collections, for the builder's "not on the trade list" search.
#
# People rarely trade only what is in the binder: once the listed cards leave a gap in value, the
# proposer goes looking through everything else the other user has made public. That can be
# thousands of rows, so unlike the trade list it is never rendered whole - the builder asks for a
# name and gets the first LIMIT matches back, as the same rows Trades::AvailableRows builds.
#
# Only rows with nothing on the trade list are searched. A listed row is already on the page, with
# its unlisted copies on offer beside the listed ones, and the same row twice would be two inputs
# writing one draft item.
#
# A blank query returns nothing rather than the first page of the collection: this is a search, and
# an alphabetical slice of somebody's cards is not an answer to anything.
module Trades
  class UnlistedRows < Service
    LIMIT = 25

    def initialize(user:, query:, except_trade: nil)
      @user = user
      @query = query.to_s.strip
      @except_trade = except_trade
    end

    def call
      return [] if @query.blank?

      AvailableRows.call(user: @user, except_trade: @except_trade, scope: scope)
    end

    private

    def scope
      @user.offerable_cards.unlisted.joins(:magic_card)
           .where('magic_cards.name ILIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%")
           .limit(LIMIT)
    end
  end
end
