module CardAnalysis
  class ReplacementFinder < Service
    CARD_TYPES = %i[regular foil proxy proxy_foil].freeze
    TYPE_LABELS = { regular: 'Regular', foil: 'Foil', proxy: 'Proxy', proxy_foil: 'Foil Proxy' }.freeze

    def initialize(magic_card:, deck:, user:, limit: nil)
      @magic_card = magic_card
      @deck = deck
      @user = user
      @limit = limit
    end

    def call
      @source_roles = CardRole.for_oracle_id(@magic_card.scryfall_oracle_id)
      return { roles: [], candidates: [] } if @source_roles.empty?

      candidate_oracle_ids = find_candidate_oracle_ids
      scored = score_candidates(candidate_oracle_ids)
      blend_edhrec_rank(scored)
      ownership = load_ownership(scored.keys)
      sorted = sort_and_limit(scored, ownership)
      cards = load_cards(sorted.map(&:first))

      {
        roles: @source_roles.map { |r| { role: r.role, effect: r.effect, confidence: r.confidence } },
        candidates: build_results(sorted, cards, ownership)
      }
    end

    private

    def find_candidate_oracle_ids
      excluded = excluded_oracle_ids
      combined = build_role_conditions

      oracle_ids = CardRole.where(combined)
                           .where.not(scryfall_oracle_id: excluded.to_a)
                           .distinct
                           .pluck(:scryfall_oracle_id)

      filter_commander_legal(oracle_ids)
    end

    def filter_commander_legal(oracle_ids)
      legal_ids = MagicCardLegality.joins(:legality)
                                   .where(legalities: { name: 'commander' }, status: 'Legal')
                                   .select(:magic_card_id)

      MagicCard.where(id: legal_ids, scryfall_oracle_id: oracle_ids, card_side: [nil, 'a'])
               .distinct.pluck(:scryfall_oracle_id)
    end

    def excluded_oracle_ids
      deck_oids = @deck.collection_magic_cards.includes(:magic_card).map { |c| c.magic_card.scryfall_oracle_id }
      deck_oids.to_set << @magic_card.scryfall_oracle_id
    end

    def build_role_conditions
      t = CardRole.arel_table
      @source_roles.map { |role| t[:role].eq(role.role).and(t[:effect].eq(role.effect)) }.reduce(:or)
    end

    def score_candidates(oracle_ids)
      source_map = @source_roles.index_by { |r| [r.role, r.effect] }
      scores = Hash.new { |h, k| h[k] = { score: 0.0, matched_roles: [] } }

      CardRole.where(scryfall_oracle_id: oracle_ids).find_each do |cr|
        accumulate_score(scores, cr, source_map)
      end

      scores
    end

    def accumulate_score(scores, candidate_role, source_map)
      source = source_map[[candidate_role.role, candidate_role.effect]]
      return unless source

      entry = scores[candidate_role.scryfall_oracle_id]
      entry[:score] += candidate_role.confidence * source.confidence
      entry[:matched_roles] << { role: candidate_role.role, effect: candidate_role.effect }
    end

    def blend_edhrec_rank(scores)
      EdhrecRankBlender.new(scores).blend
    end

    def load_ownership(oracle_ids)
      return {} unless @user

      records = CollectionMagicCard
                .joins(:collection, :magic_card)
                .includes(:collection, magic_card: :boxset)
                .where(collections: { user_id: @user.id })
                .where.not(collection_id: @deck.id)
                .where(magic_cards: { scryfall_oracle_id: oracle_ids })
                .where(staged: false, needed: false)

      records.group_by { |r| r.magic_card.scryfall_oracle_id }.transform_values do |copies|
        copies.flat_map { |c| ownership_entries_for(c) }
      end
    end

    def ownership_entries_for(cmc)
      available = DeckBuilder::StagedQuantities.calculate_available(source: cmc)

      CARD_TYPES.filter_map do |type|
        next unless available[type].positive?

        { collection_id: cmc.collection_id, collection_name: cmc.collection.name,
          magic_card_id: cmc.magic_card_id, magic_card: cmc.magic_card, card_type: type,
          type_label: TYPE_LABELS[type], available: available[type] }
      end
    end

    def sort_and_limit(scored, ownership)
      filtered = filter_by_color_identity(scored)

      sorted = filtered.sort_by do |oid, data|
        [ownership.key?(oid) ? 0 : 1, -data[:score]]
      end

      @limit ? sorted.first(@limit) : sorted
    end

    def filter_by_color_identity(scored)
      commander_color_ids = load_commander_color_ids
      return scored if commander_color_ids.nil?

      candidate_colors = build_candidate_color_map(scored.keys)

      scored.select do |oid, _data|
        card_colors = candidate_colors[oid] || Set.new
        card_colors.subset?(commander_color_ids)
      end
    end

    def build_candidate_color_map(oracle_ids)
      MagicCardColorIdent
        .where(magic_card_id: representative_card_ids(oracle_ids))
        .joins(:magic_card)
        .pluck('magic_cards.scryfall_oracle_id', :color_id)
        .group_by(&:first)
        .transform_values { |pairs| pairs.to_set(&:last) }
    end

    def load_commander_color_ids
      commanders = @deck.commanders
      return nil if commanders.empty?

      commander_card_ids = commanders.map(&:magic_card_id)
      MagicCardColorIdent.where(magic_card_id: commander_card_ids).pluck(:color_id).to_set
    end

    def representative_card_ids(oracle_ids)
      MagicCard.where(scryfall_oracle_id: oracle_ids, card_side: [nil, 'a'])
               .group(:scryfall_oracle_id)
               .pluck(Arel.sql('MAX(id)'))
    end

    def load_cards(oracle_ids)
      return {} if oracle_ids.empty?

      MagicCard.where(scryfall_oracle_id: oracle_ids, card_side: [nil, 'a'])
               .includes(:boxset)
               .order('boxsets.release_date DESC')
               .index_by(&:scryfall_oracle_id)
    end

    def build_results(sorted, cards, ownership)
      sorted.flat_map do |oid, data|
        card = cards[oid]
        next unless card

        sources = ownership[oid] || []
        base = { magic_card: card, score: data[:score].round(3), matched_roles: data[:matched_roles] }

        if sources.any?
          sources.map do |source|
            base.merge(
              owned: true, magic_card: source[:magic_card], collection_id: source[:collection_id],
              collection_name: source[:collection_name], magic_card_id: source[:magic_card_id],
              card_type: source[:card_type], type_label: source[:type_label], available: source[:available]
            )
          end
        else
          [base.merge(owned: false)]
        end
      end.compact
    end
  end
end
