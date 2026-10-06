# "Anything I own that goes up to $1 or more, or back down to $0.90 or less", checked against one
# day's prices.
#
# PriceAlerts::SyncBand moves each card's side and says which cards just went on the band's
# worklist, and which way; this sends one notification per band for them, however many there are,
# naming the first few. The sync runs in the same transaction as the alert's stamp, so a retried run finds the
# cards already moved and the band already done.
module PriceAlerts
  class EvaluateBands < Evaluation
    KIND = 'price_band_crossed'.freeze
    NAMED = 3

    def call
      due(PriceAlert.active.bands).includes(:user).find_each { |band| evaluate(band) }
    end

    private

    def evaluate(band)
      PriceAlert.transaction do
        listed = SyncBand.call(band: band, on: @price_date)
        listed.empty? ? record(band) : record(band, kind: KIND, payload: payload(band, listed))
      end
    end

    def payload(band, listed)
      count = listed.size
      { subject: "#{count} #{'card'.pluralize(count)} you own", count: count,
        movement: movement(band, listed.map { |holding| holding[:moved] }), names: names(listed) }
    end

    # "reached $1.00 or more", "dropped back to $0.90 or less", or for a day with both,
    # "crossed your $0.90-$1.00 band (3 up, 1 down)". A `below` band's move is "dropped under $1.00".
    def movement(band, moves)
      ups = moves.count('up')
      downs = moves.size - ups
      if ups.positive? && downs.positive?
        "crossed your #{money(band.from_price)}-#{money(band.threshold_price)} band (#{ups} up, #{downs} down)"
      elsif moves.first == band.reach_move
        line = money(band.threshold_price)
        band.reach_move == 'up' ? "reached #{line} or more" : "dropped under #{line}"
      else
        "dropped back to #{money(band.from_price)} or less"
      end
    end

    # "Sol Ring, Arcane Signet, Command Tower and 2 more", front faces only
    def names(listed)
      named = listed.map { |holding| holding[:name].to_s.split('//').first.strip }.uniq
      shown = named.first(NAMED)
      rest = named.size - shown.size

      rest.positive? ? "#{shown.join(', ')} and #{rest} more" : shown.to_sentence
    end
  end
end
