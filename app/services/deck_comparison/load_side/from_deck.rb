# One of the viewer's own decks as the cards of a comparison side.
#
# The deck is looked up through the viewer's collections and nowhere else, which is the whole
# authorization rule: whatever the reason no deck came back, the answer is the same error.
#
# The rows are the ones the deck builder shows (DeckBuilder::LoadCards): staged, needed and finalized
# owned - minus the sideboard, which a pasted side drops too. A comparison is by card rather than by
# printing, so rows on one oracle id - a staged copy beside an owned one, or two printings - merge into
# one card that keeps the first row's printing. A row with no oracle id is keyed by its own card id; a
# pasted card always has an oracle id, so that key can never match one and the card just lands in an
# "only" tab.
module DeckComparison
  class LoadSide
    class FromDeck < Service
      ERROR = 'Pick one of your decks.'.freeze

      def initialize(viewer:, deck_id:)
        @viewer = viewer
        @deck_id = deck_id
      end

      def call
        deck = @viewer.collections.decks.find_by(id: @deck_id) if @viewer
        return { error: ERROR } if deck.nil?

        { deck_name: deck.name, cards: cards(rows(deck)) }
      end

      private

      # the sideboard is dropped in Ruby: board_type is nullable, and a SQL `!=` would lose those rows too
      def rows(deck)
        all_cards = deck.collection_magic_cards
                        .includes(magic_card: %i[boxset sub_types colors magic_card_color_idents])

        (all_cards.staged + all_cards.needed + all_cards.finalized.owned)
          .uniq.reject { |row| row.board_type == 'sideboard' }
      end

      def cards(rows)
        fronts = front_faces(rows)

        rows.group_by { |row| key(row.magic_card) }.map do |key, merged|
          first = merged.first

          { key: key,
            magic_card: fronts.fetch(first.magic_card.other_face_uuid, first.magic_card),
            quantity: merged.sum(&:display_quantity),
            board_type: merged.any?(&:commander?) ? 'commander' : first.board_type,
            unit_price: first.display_unit_price }
        end
      end

      def key(magic_card)
        magic_card.scryfall_oracle_id || "card:#{magic_card.id}"
      end

      # { a back face's other_face_uuid => its front face }, in one query - MagicCard#front_face is a
      # find_by per card
      def front_faces(rows)
        uuids = rows.map(&:magic_card).select { |card| card.card_side == 'b' }.filter_map(&:other_face_uuid)
        return {} if uuids.empty?

        MagicCard.where(card_uuid: uuids)
                 .includes(:boxset, :sub_types, :colors, :magic_card_color_idents)
                 .index_by(&:card_uuid)
      end
    end
  end
end
