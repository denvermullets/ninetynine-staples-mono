# Adds any-printing wants for cards already known by oracle id - the step the bulk importers share once
# a pasted name or a proxy has been pinned to a card. `quantities` is { scryfall_oracle_id => quantity }.
#
# A card the user already wants in any form is left alone and handed back in :already_wanted: adding a
# list twice should not bump quantities or stack a second row on a specific-printing want.
#
# The printing a new row points at is only an anchor, since any printing satisfies it. The cheapest
# priced front face from an ordinary paper set is used, so the list's price column reads as what filling
# the want would cost - and not what a gold-bordered World Championship copy or an Arena-only card costs.
module WantList
  class AddByOracle < Service
    # sets whose copies are a poor stand-in for "the card": digital, gold-bordered, silver-bordered, oddball
    UNUSUAL_SET_TYPES = %w[alchemy funny memorabilia minigame token treasure_chest vanguard].freeze

    CHOOSE_PRINTING_SQL = <<~SQL.squish.freeze
      magic_cards.scryfall_oracle_id,
      magic_cards.card_side = 'b' ASC NULLS FIRST,
      COALESCE(boxsets.set_type IN (#{UNUSUAL_SET_TYPES.map { |type| "'#{type}'" }.join(', ')}), FALSE) ASC,
      magic_cards.normal_price > 0 DESC NULLS LAST,
      magic_cards.normal_price ASC NULLS LAST,
      boxsets.release_date DESC NULLS LAST,
      magic_cards.id ASC
    SQL

    # the cards a want can be anchored to - the same ones a typed name can resolve to
    def self.candidates
      Decklist::Resolve.candidates
    end

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
      return {} if oracle_ids.empty?

      self.class.candidates.left_joins(:boxset)
          .where(scryfall_oracle_id: oracle_ids)
          .where.not(id: @user.want_list_items.select(:magic_card_id))
          .select('DISTINCT ON (magic_cards.scryfall_oracle_id) magic_cards.*')
          .order(Arel.sql(CHOOSE_PRINTING_SQL))
          .index_by(&:scryfall_oracle_id)
    end
  end
end
