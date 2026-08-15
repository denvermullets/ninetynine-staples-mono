module CollectionStats
  # Owned creature counts per subtype per colour identity - the tribal half of the brew page's fit
  # score, since the card_roles taxonomy has no concept of "is a Goblin".
  #
  # Same 32-bucket shape as BuildableProfile and the same reason for it: a commander that pays off a
  # creature type wants those creatures, and asking "how many Goblins could this commander play" has
  # to respect colour identity or a mono-red Goblin lord scores off your Jund goblins.
  #
  # Only the subtypes actually named by a candidate commander are counted. The full cross product is
  # 377 subtypes x 32 masks; a page of commanders names a couple of dozen types between them, so
  # filtering here keeps the aggregate small rather than building a table nothing reads.
  class BuildableTribes < Base
    include MaskedOracles

    def initialize(collection_ids:, subtypes:)
      super(collection_ids: collection_ids)
      @subtypes = Array(subtypes).uniq
    end

    # -> { mask => { 'Goblin' => 12, ... } }, masks with nothing owned omitted
    def call
      return {} if no_collections? || @subtypes.empty?

      aggregate.each_with_object({}) do |(mask, name, count), profile|
        (profile[mask] ||= {})[name] = count.to_i
      end
    end

    private

    # COUNT(DISTINCT oracle id), matching BuildableProfile - four printings of Krenko is one Goblin
    # you can put in the deck.
    def aggregate
      masked_oracles
        .joins('JOIN magic_cards tribe_cards ON tribe_cards.scryfall_oracle_id::text = ' \
               'masked.scryfall_oracle_id')
        .joins('JOIN magic_card_sub_types ON magic_card_sub_types.magic_card_id = tribe_cards.id')
        .joins('JOIN sub_types ON sub_types.id = magic_card_sub_types.sub_type_id')
        .where(sub_types: { name: @subtypes })
        .group(Arel.sql('masked.mask'), Arel.sql('sub_types.name'))
        .pluck(Arel.sql('masked.mask'), Arel.sql('sub_types.name'),
               Arel.sql('COUNT(DISTINCT masked.scryfall_oracle_id)'))
    end
  end
end
