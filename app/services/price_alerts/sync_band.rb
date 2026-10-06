# Places every card a price band watches against the band, one PriceBandCard per printing and
# finish, and returns the cards that just went on its worklist, each with the way it `moved`.
#
# Per card, for a `both` band ($0.90 / $1.00, the sleeve swap):
#
# - no row yet: the card is new to the band, so its side is learned rather than told. At $1.00 or
#   more it is `crossed`, otherwise `armed` - a card at $0.95 counts as armed, it has not reached
#   the line. Nothing is listed, so a card added at $2 is taken as sleeved for $2. The exception is
#   `audit` (the "put them on the list" choice when a band is made), which lists the cards already
#   at $1.00 or more.
# - armed, and the price reaches $1.00: `crossed`, listed as moved up.
# - crossed, and the price comes back to $0.90 or less: `armed`, listed as moved down - the $2 card
#   from a fresh set that the market flooded down to $0.50.
# - between the two lines nothing changes either way.
#
# A listed move nobody has handled yet that the price undoes - up, then back down before the card
# was re-sleeved - comes off the list, since the card is where it started. An `above` band reads
# the same but lists only the move up: coming back to $0.90 re-arms it quietly. A `below` band is
# that the other way up, listing only the move down.
#
# A move outside the band's buylist range still moves the card's side, but lists nothing. No price
# (or 0) is no data, so a card without one keeps whatever row it has.
#
# A row for a card the band no longer sees - sold, moved out of the collection, a finish no longer
# held - is deleted, so a card coming back is learned afresh rather than judged on an old side.
module PriceAlerts
  class SyncBand < Service
    def initialize(band:, on: Date.current, audit: false)
      @band = band
      @on = on.to_date
      @audit = audit
      @now = Time.current
    end

    def call
      held = CollectionStats::FinishHoldings.for_band(@band).call
      learned, known = held.select { |holding| holding[:price]&.positive? }
                           .partition { |holding| state_for(holding).nil? }

      prune(held)
      PriceBandCard.insert_all(learned.map { |holding| learn(holding) }) if learned.any?
      known.filter_map { |holding| moved(holding) }
    end

    private

    def moved(holding)
      moved = move(state_for(holding), holding)
      holding.merge(moved: moved) if moved
    end

    # queried rather than read through band.band_cards, which would cache the rows from before the
    # insert on the caller's band
    def states
      @states ||= PriceBandCard.where(price_alert_id: @band.id).index_by { |state| [state.magic_card_id, state.finish] }
    end

    def state_for(holding)
      states[key(holding)]
    end

    def key(holding)
      [holding[:magic_card_id], holding[:finish]]
    end

    # the row for a card the band has not seen before
    def learn(holding)
      reached = @band.reaches?(holding[:price])
      row = { price_alert_id: @band.id, magic_card_id: holding[:magic_card_id], finish: holding[:finish],
              state: reached ? 'crossed' : 'armed', crossed_on: nil, crossed_price: nil, moved: nil,
              handled_at: nil }
      return row unless reached && @audit && listable?(holding)

      row.merge(crossed_on: @on, crossed_price: holding[:price], moved: @band.reach_move)
    end

    # the way the card just went on the list, or nil
    def move(state, holding)
      price = holding[:price]
      if state.armed? && @band.reaches?(price)
        list(state, 'crossed', @band.reach_move, holding)
      elsif state.crossed? && @band.returns_at?(price)
        @band.two_way? ? list(state, 'armed', @band.return_move, holding) : unlist(state, 'armed')
      end
    end

    # a move still waiting to be handled is undone rather than replaced
    def list(state, side, moved, holding)
      return unlist(state, side) if state.to_do? || !listable?(holding)

      state.update_columns(state: side, crossed_on: @on, crossed_price: holding[:price], moved: moved,
                           handled_at: nil, updated_at: @now)
      moved
    end

    def unlist(state, side)
      state.update_columns(state: side, crossed_on: nil, crossed_price: nil, moved: nil, handled_at: nil,
                           updated_at: @now)
      nil
    end

    def listable?(holding)
      @band.buylist_in_range?(holding[:buylist])
    end

    def prune(held)
      gone = states.except(*held.map { |holding| key(holding) }).values.map(&:id)

      PriceBandCard.where(id: gone).delete_all if gone.any?
    end
  end
end
