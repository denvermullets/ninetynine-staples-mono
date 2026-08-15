module Commanders
  # The commander universe the brew page scores, as plain tuples with their colour identity mask
  # already resolved.
  #
  # One printing per oracle id - identity, rank and mana value are properties of the card, not of the
  # printing, and carrying every reprint would multiply the list by the reprint count for no new
  # information. MAX(id) picks the newest, the same way CardAnalysis::ColorIdentityGate does.
  #
  # Every hard filter lives here rather than in Discovery's Ruby: these are the ones that can be
  # answered without knowing anything about the collection, so answering them in SQL means the
  # scoring pass never sees the rows.
  class Candidates < Service
    def initialize(band: nil, colors: nil, code: nil, owned_collection_ids: nil)
      @band = band
      @colors = colors
      @code = code
      @owned_collection_ids = owned_collection_ids
    end

    COLUMNS = %i[magic_card_id oracle_id name text edhrec_rank mana_value mask].freeze

    # -> [{ oracle_id:, magic_card_id:, name:, text:, edhrec_rank:, mana_value:, mask: }]
    def call
      tuples = rows.map { |tuple| COLUMNS.zip(tuple).to_h }
      tuples.each { |row| row[:mask] = row[:mask].to_i }

      tuples.select { |row| in_colors?(row[:mask]) }
    end

    private

    def rows
      MagicCard
        .where(id: representative_ids)
        .left_joins(:magic_card_color_idents)
        .joins('LEFT JOIN colors ON colors.id = magic_card_color_idents.color_id')
        .group('magic_cards.id')
        .pluck(:id, Arel.sql('magic_cards.scryfall_oracle_id::text'), :name, :text, :edhrec_rank,
               :mana_value, Arel.sql("COALESCE(BIT_OR(#{ColorMask.bit_case}), 0)"))
    end

    # Filters that narrow which cards are commanders at all run before the representative printing is
    # chosen - a set filter has to pick the printing in that set, not the newest one overall.
    def representative_ids
      scope = MagicCard.where(can_be_commander: true, card_side: [nil, 'a'])
      scope = scope.where(edhrec_rank: @band) if @band
      scope = scope.where(boxset: Boxset.where(code: @code)) if @code.present?
      scope = scope.where(scryfall_oracle_id: owned_oracle_ids) if @owned_collection_ids

      scope.group(:scryfall_oracle_id).pluck(Arel.sql('MAX(magic_cards.id)'))
    end

    def owned_oracle_ids
      CollectionMagicCard
        .joins(:magic_card)
        .where(collection_id: @owned_collection_ids, staged: false, needed: false)
        .distinct
        .pluck('magic_cards.scryfall_oracle_id')
    end

    # Subset, not intersection: picking WUB means "commanders I could sleeve up in Esper or inside
    # it", which is the question the filter bar is asking. A Jund commander is not a WUB brew.
    def in_colors?(mask)
      return true if @colors.blank?

      mask.nobits?(~@colors)
    end
  end
end
