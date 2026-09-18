# The builder's starting quantities when it is opened from the want matches page: the recipient's
# side filled with the copies that meet the proposer's wants.
#
# `want_ids` comes from the query string, so it is only ever read through the proposer's own want
# list - an id that is not theirs, or was removed since the matches page loaded, is dropped. So is a
# want nothing on the recipient's side meets any more: `rows` is Trades::AvailableRows for the
# recipient, already net of copies other trades hold, and the builder can only draft rows it shows.
#
# Each want takes up to its quantity in the finishes it accepts, walking the rows in the order the
# builder lists them; an any-finish want takes regular copies before foils. Two wants can meet the
# same row (one for this printing, one for any printing of the card), so what one want takes comes
# out of what the next can.
#
# Returns { row_id => { quantity:, foil_quantity: } }, the same shape as Trades::CounterDraft.
module Trades
  class WantDraft < Service
    FINISHES = {
      'any' => %i[quantity foil_quantity],
      'non_foil' => %i[quantity],
      'foil' => %i[foil_quantity]
    }.freeze

    def initialize(proposer:, want_ids:, rows:)
      @proposer = proposer
      @want_ids = want_ids
      @rows = rows
    end

    def call
      return {} if @want_ids.empty? || @rows.empty?

      wants.each_with_object({}) { |want, draft| take(want, draft) }
    end

    private

    def wants
      @proposer.want_list_items.where(id: @want_ids).order(:id)
    end

    # what each row has left once the wants before this one have taken their copies
    def left
      @left ||= @rows.to_h { |row| [row.id, { quantity: row.quantity, foil_quantity: row.foil_quantity }] }
    end

    def take(want, draft)
      needed = want.quantity

      @rows.each do |row|
        break unless needed.positive?
        next unless want.satisfied_by?(row.magic_card)

        needed -= take_from(row.id, FINISHES.fetch(want.foil_preference), needed, draft)
      end
    end

    # up to `needed` copies off one row, finish by finish; returns how many it took
    def take_from(row_id, fields, needed, draft)
      fields.sum do |field|
        taken = [needed, left[row_id][field]].min
        next 0 unless taken.positive?

        left[row_id][field] -= taken
        needed -= taken
        (draft[row_id] ||= { quantity: 0, foil_quantity: 0 })[field] += taken
        taken
      end
    end
  end
end
