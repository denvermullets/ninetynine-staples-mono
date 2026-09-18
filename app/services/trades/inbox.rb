# The three tabs on /trades, and how many trades sit behind each.
#
#   incoming - open trades someone proposed to `user`
#   outgoing - open trades `user` proposed
#   history  - every closed trade, whichever side `user` was on
#
# "Open" is Trade::OPEN_STATUSES, so an accepted trade stays in incoming/outgoing until both parties
# have confirmed receipt - there is still something to do on it.
module Trades
  class Inbox < Service
    TABS = %w[incoming outgoing history].freeze

    def initialize(user:, tab: nil)
      @user = user
      @tab = TABS.include?(tab) ? tab : TABS.first
    end

    def call
      trades = scope(@tab).includes(:proposer, :recipient, :trade_items).order(updated_at: :desc, id: :desc)

      { tab: @tab, trades: trades, counts: TABS.index_with { |tab| scope(tab).count } }
    end

    private

    def scope(tab)
      case tab
      when 'incoming' then Trade.open.where(recipient_id: @user.id)
      when 'outgoing' then Trade.open.where(proposer_id: @user.id)
      else Trade.involving(@user).where.not(status: Trade::OPEN_STATUSES)
      end
    end
  end
end
