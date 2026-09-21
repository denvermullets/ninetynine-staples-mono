# A pasted decklist as the cards of a comparison side.
#
# Reading and resolving the text is the want importer's (Decklist::Parse, Decklist::Resolve); what is
# decided here is what a deck comparison makes of it. The endpoint is public, so the text is capped
# before it is parsed at all. Sideboard, maybeboard and token lines are not part of a Commander deck
# and are dropped - the parser only tags them. What is left is capped well under the want importer's
# 500: a legal deck is 100 cards, and MAX_CARDS only leaves room for one still being cut down.
#
# Two typed names on one oracle id ("Fire // Ice" and a lone "Ice") are one card, and a paste names no
# printing, so each card is shown as Decklist::DefaultPrintings' pick.
#
# Whatever could not be used comes back as typed, so the list can be fixed and pasted again.
module DeckComparison
  class LoadSide
    class FromPaste < Service
      MAX_LENGTH = 100_000
      MAX_CARDS = 150
      IGNORED_BOARDS = %w[sideboard maybeboard tokens].freeze
      PRELOAD = [:boxset, :sub_types, :colors, { magic_card_color_idents: :color }].freeze

      def initialize(text:)
        @text = text
      end

      def call
        return { error: 'That list is too long.' } if @text.length > MAX_LENGTH

        entries = deck_entries
        return { error: "Paste at most #{MAX_CARDS} cards per deck." } if entries.size > MAX_CARDS

        build(Decklist::Resolve.call(entries: entries))
      end

      private

      def deck_entries
        Decklist::Parse.call(text: @text).reject { |_key, entry| IGNORED_BOARDS.include?(entry[:board]) }
      end

      def build(resolved)
        by_oracle_id = resolved[:resolved].group_by { |entry| entry[:oracle_id] }
        printings = Decklist::DefaultPrintings.call(oracle_ids: by_oracle_id.keys, preload: PRELOAD)
        printed, unprinted = by_oracle_id.partition { |oracle_id, _entries| printings.key?(oracle_id) }

        { cards: printed.map { |oracle_id, entries| card(printings[oracle_id], entries) },
          ambiguous: report(resolved[:ambiguous]),
          unresolved: report(resolved[:unresolved] + unprinted.flat_map(&:last)) }
      end

      def card(printing, entries)
        { key: printing.scryfall_oracle_id,
          magic_card: printing,
          quantity: entries.sum { |entry| entry[:quantity] },
          board_type: entries.any? { |entry| entry[:board] == 'commander' } ? 'commander' : 'mainboard',
          unit_price: printing.display_price.to_f }
      end

      def report(entries)
        entries.map { |entry| entry.slice(:name, :quantity) }
      end
    end
  end
end
