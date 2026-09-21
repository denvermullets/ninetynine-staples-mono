# Adds any-printing wants for cards already known by oracle id - the step the bulk importers share once
# a pasted name or a proxy has been pinned to a card. `quantities` is { scryfall_oracle_id => quantity }.
#
# A card the user already wants in any form is left alone and handed back in :already_wanted: adding a
# list twice should not bump quantities or stack a second row on a specific-printing want.
#
# The printing a new row points at is only an anchor, since any printing satisfies it. Which one, and
# why the cheapest ordinary printing, is Decklist::DefaultPrintings.
module WantList
  class AddByOracle < Service
    def initialize(user:, quantities:)
      @user = user
      @quantities = quantities
    end

    def call
      already = wanted_oracle_ids

      { added: create_items(@quantities.except(*already)), already_wanted: already }
    end

    private

    # any row counts, specific printing included
    def wanted_oracle_ids
      @user.want_list_items.where(scryfall_oracle_id: @quantities.keys).distinct.pluck(:scryfall_oracle_id)
    end

    def create_items(quantities)
      printings = anchor_printings(quantities.keys)

      quantities.filter_map do |oracle_id, quantity|
        card = printings[oracle_id]
        next unless card

        item = @user.want_list_items.new(magic_card: card, quantity: quantity, any_printing: true)
        item if item.save
      end
    end

    # one printing per oracle id, skipping any the user already has a row on
    def anchor_printings(oracle_ids)
      Decklist::DefaultPrintings.call(oracle_ids: oracle_ids,
                                      except_card_ids: @user.want_list_items.select(:magic_card_id))
    end
  end
end
