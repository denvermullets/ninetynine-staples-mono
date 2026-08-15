module CardAnalysis
  class ReplacementFinder < Service
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
      MagicCard.commander_legal
               .where(scryfall_oracle_id: oracle_ids, card_side: [nil, 'a'])
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
      ConfidenceScorer.call(
        rows: ConfidenceScorer.rows_for(oracle_ids),
        targets: @source_roles.to_h { |role| [[role.role, role.effect], role.confidence] }
      )
    end

    def blend_edhrec_rank(scores)
      EdhrecRankBlender.new(scores).blend
    end

    def load_ownership(oracle_ids)
      DeckBuilder::OwnershipOverlay.call(
        user: @user, oracle_ids: oracle_ids, exclude_collection_id: @deck.id
      )
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

      # The gate returns survivors in the order it was given them, so slicing preserves scored's own key
      # order rather than reshuffling it.
      passing = ColorIdentityGate.call(oracle_ids: scored.keys, allowed_color_ids: commander_color_ids)

      scored.slice(*passing)
    end

    def load_commander_color_ids
      commanders = @deck.commanders
      return nil if commanders.empty?

      ColorIdentityGate.color_ids_for(magic_card_ids: commanders.map(&:magic_card_id))
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

        sources.any? ? sources.map { |source| owned_result(base, source) } : [base.merge(owned: false)]
      end.compact
    end

    def owned_result(base, source)
      base.merge(
        owned: true, magic_card: source[:magic_card], collection_id: source[:collection_id],
        collection_name: source[:collection_name], magic_card_id: source[:magic_card_id],
        card_type: source[:card_type], type_label: source[:type_label], available: source[:available]
      )
    end
  end
end
