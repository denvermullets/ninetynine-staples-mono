# Creates a trade proposal with cards on both sides, in one transaction.
#
# Each item names a collection row and how many regular / foil copies of it are on offer. The side
# tells us whose row it must be: a proposer-side item has to belong to the proposer, and vice versa.
#
# Availability is the copies the owner has on the row minus the ones they already have committed to
# other open trades (proposed or accepted). Without that second half a user could offer the same
# playset to five people and only find out when four of them accepted - the counts on the collection
# row don't move until a trade completes, so they can't be the whole answer on their own.
#
# The trade list is not the ceiling. Any real copy in a public collection can be asked for, because
# a trade rarely balances on the binder alone; an item that reaches past what is left of the owner's
# trade list is stamped `off_list`, so the trade page can tell them that is what is being asked.
#
# A counter-offer is a proposal with a `parent`: the trade it answers. Only that trade's recipient can
# send one, back to its proposer, while it is still proposed. The parent is declined - with a
# `countered` event rather than a `declined` one, so its timeline says why - in the same transaction
# the counter is written, and before its items are checked: once the parent is closed its copies stop
# counting as committed, which is what lets the counter put the same cards back on the table.
#
# Prices are snapshotted here. Both parties agreed on the numbers they were shown, and a card
# spiking between proposal and acceptance shouldn't silently rewrite the deal.
module Trades
  class Propose < Service
    PRICE_COLUMNS = {
      unit_price_snapshot: :normal_price,
      unit_foil_price_snapshot: :foil_price,
      unit_buylist_snapshot: :ck_buylist_normal_price,
      unit_buylist_foil_snapshot: :ck_buylist_foil_price
    }.freeze

    def initialize(proposer:, recipient:, items:, message: nil, parent: nil)
      @proposer = proposer
      @recipient = recipient
      @items = Array(items).map { |item| item.to_h.symbolize_keys }
      @message = message
      @parent = parent
    end

    def call
      error = guard || counter_guard
      return { success: false, error: error } if error

      trade = build_trade
      { success: true, trade: trade }
    rescue ProposalError => e
      { success: false, error: e.message }
    end

    class ProposalError < StandardError; end

    private

    def guard
      return 'A trade needs two different users.' if @proposer.nil? || @recipient.nil? || @proposer.id == @recipient.id
      return "#{@recipient.username} is not accepting trade offers." unless @recipient.trades_public?
      return 'A trade needs at least one card.' if @items.empty?

      nil
    end

    def counter_guard
      return nil if @parent.nil?
      return nil if @parent.counterable_by?(@proposer) && @parent.proposer_id == @recipient.id

      'You can only counter an open offer that was made to you.'
    end

    def build_trade
      ActiveRecord::Base.transaction do
        close_parent if @parent
        trade = Trade.create!(proposer: @proposer, recipient: @recipient, status: 'proposed', message: @message,
                              parent_trade: @parent)
        @items.each { |item| trade.trade_items.create!(item_attributes(item)) }
        trade.trade_events.create!(user: @proposer, event: 'proposed')
        Notifications::Deliver.call(user: @recipient, kind: @parent ? 'trade_countered' : 'trade_proposed',
                                    notifiable: trade)
        trade
      end
    end

    # locked and re-checked, so the parent cannot be accepted, cancelled or countered twice while the
    # counter is being written
    def close_parent
      @parent.lock!
      raise ProposalError, "This trade is already #{@parent.status}." unless @parent.proposed?

      @parent.update!(status: 'declined')
      @parent.trade_events.create!(user: @proposer, event: 'countered')
    end

    def item_attributes(item)
      side = item[:side].to_s
      raise ProposalError, 'Every card has to be on one side of the trade.' unless Trade::SIDES.include?(side)

      card = owned_row(item, side)
      wanted = { quantity: requested(item, :quantity), foil_quantity: requested(item, :foil_quantity) }
      held = Committed.call(user: owner_of(side), collection_magic_card_ids: [card.id])[card.id]
      check_availability(card, wanted, held)

      { collection_magic_card: card, magic_card_id: card.magic_card_id, side: side,
        off_list: off_list?(card, wanted, held) }.merge(wanted, snapshots(card.magic_card))
    end

    def owner_of(side)
      side == 'proposer' ? @proposer : @recipient
    end

    # The row has to be one the other user could have found for themselves - a real copy in a public
    # collection, User#offerable_cards. Anything else and the trade would be built on copies its
    # counterparty was never shown.
    def owned_row(item, side)
      owner = owner_of(side)
      row = owner.offerable_cards.find_by(id: item[:collection_magic_card_id])
      raise ProposalError, "#{owner.username} does not have that card to trade." if row.nil?

      row
    end

    def requested(item, key)
      value = item[key].to_i
      raise ProposalError, 'A card cannot be traded in negative quantities.' if value.negative?

      value
    end

    # `held` is what the owner's other open trades already hold of this row - Trades::Committed
    def check_availability(card, wanted, held)
      name = card.magic_card.name

      shortfall(name, wanted[:quantity], card.quantity.to_i - held[:quantity], '')
      shortfall(name, wanted[:foil_quantity], card.foil_quantity.to_i - held[:foil_quantity], 'foil ')
    end

    # held copies come off the trade list first, the same way Trades::AvailableRows counts them
    def off_list?(card, wanted, held)
      wanted[:quantity] > card.trade_quantity - held[:quantity] ||
        wanted[:foil_quantity] > card.trade_foil_quantity - held[:foil_quantity]
    end

    def shortfall(name, wanted, available, finish)
      return if wanted <= available

      left = [available, 0].max
      raise ProposalError, "Only #{left} #{finish}#{'copy'.pluralize(left)} of #{name} are available to trade."
    end

    def snapshots(magic_card)
      PRICE_COLUMNS.transform_values { |column| magic_card.public_send(column).to_d }
    end
  end
end
