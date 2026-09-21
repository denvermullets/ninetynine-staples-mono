# Pins the typed names from Decklist::Parse to cards, by oracle id, and says which names it could not.
#
# Nothing else in the app resolves a typed card name: precons arrive keyed by MTGJSON uuid, CSV imports
# by Scryfall id, and the deck builder's bulk import searches one line at a time for the user to pick.
# A pasted list can be hundreds of lines, so names are resolved in batched lookups - full names first
# ("Fire // Ice"), then single faces ("Fire") for whatever is left, then the alternate names some
# printings carry ("Balin's Tomb" for Ancient Tomb), which deck sites export as typed.
#
# A name that lands on more than one oracle id (the Unfinity attraction variants, "Fire" as a face of
# two split cards) is handed back as ambiguous rather than guessed.
#
# Entries are never merged per card. Two typed names can land on one oracle id ("Fire // Ice" and a
# lone "Ice"), and a caller reporting back to the user needs the names as they were typed, so summing
# those is left to whoever wants it.
module Decklist
  class Resolve < Service
    # the printings a typed name may resolve to: tokens share names with real cards, and a printing
    # with no oracle id cannot be told apart from any other
    def self.candidates
      MagicCard.where(is_token: false).where.not(scryfall_oracle_id: nil)
    end

    # tried in this order, each only for the names the ones before it left over
    NAME_COLUMNS = %i[name face_name flavor_name].freeze

    # entries is Decklist::Parse's hash, keyed by normalized name
    def initialize(entries:)
      @entries = entries
    end

    def call
      oracle_ids = NAME_COLUMNS.each_with_object({}) do |column, found|
        found.merge!(lookup(column, @entries.keys - found.keys))
      end

      @entries.each_with_object({ resolved: [], ambiguous: [], unresolved: [] }) do |(key, entry), result|
        ids = oracle_ids[key]

        if ids.nil? then result[:unresolved] << entry
        elsif ids.one? then result[:resolved] << entry.merge(oracle_id: ids.first)
        else result[:ambiguous] << entry
        end
      end
    end

    private

    # { normalized_name => [every oracle id the name could mean] }
    def lookup(column, keys)
      return {} if keys.empty?

      lowered = MagicCard.arel_table[column].lower

      self.class.candidates.where(lowered.in(keys))
          .distinct
          .pluck(lowered, :scryfall_oracle_id)
          .group_by(&:first)
          .transform_values { |rows| rows.map(&:last) }
    end
  end
end
