module CardAnalysis
  # The commander -> pool direction: given a commander, what should the other 99 be?
  #
  # Ranked so cards you already own that nobody plays float up. Fit leads and obscurity breaks ties - a
  # card has to actually do the thing before being interesting for being unplayed - otherwise the list
  # fills with cards that are unplayed because they are bad.
  #
  # The only thing standing between this and a list of draft chaff is the CardRole::HIGH_CONFIDENCE gate.
  class CommanderSynergy < Service
    # Cards matching a role the deck needs but the commander does not theme still have to be orderable
    # against each other, so a role the commander never mentions still carries weight - just much less
    # than one it does.
    BASELINE_WEIGHT = 0.35

    DEFAULT_PER_BUCKET = 12

    # Not a card_roles role - a bucket of its own for owned cards that finish a combo the deck is one
    # card short of. See ComboPieces.
    COMBO_ROLE = 'combo_pieces'.freeze

    # rubocop:disable Metrics/ParameterLists -- every one of these is a real axis of the query and
    # collapsing them into an options hash would only hide that from callers.
    def initialize(commander:, user: nil, deck: nil, role: nil, owned_only: true, limit: DEFAULT_PER_BUCKET)
      @commander = commander
      @user = user
      @deck = deck
      @role = role.presence
      @owned_only = owned_only
      @limit = limit
    end
    # rubocop:enable Metrics/ParameterLists

    def call
      themes = merged_themes
      entries = build_entries(*scored_candidates(themes))

      { commander: @commander, themes: themes, roles: all_roles(themes),
        buckets: SuggestionHydrator.call(buckets: bucket(entries, themes)) }
    end

    private

    # Role matches and combo pieces share one gate and one ownership lookup.
    # -> [scored, ranks, ownership]
    def scored_candidates(themes)
      rows = candidate_role_rows(themes)
      pieces = combo_pieces
      ranks = gate(rows.map(&:first) | pieces.keys)
      scored = score(rows.select { |oracle_id, _r, _e, _c| ranks.key?(oracle_id) }, themes)
      ownership = load_ownership(scored.keys | (pieces.keys & ranks.keys))
      claim_combo_pieces(scored, pieces, ownership)
      [scored, ranks, ownership]
    end

    # A deck's commanders are the truth when there is a deck - partners mean two cards and a merged
    # identity. The passed commander is the fallback for callers with no deck yet.
    def commander_cards
      @commander_cards ||= begin
        from_deck = @deck ? @deck.commanders.map(&:magic_card) : []
        (from_deck.presence || [@commander]).uniq(&:id)
      end
    end

    # Partners merge by taking the stronger pull on each pair rather than summing, so two commanders that
    # both want tokens do not out-weigh a single commander that wants them just as much.
    def merged_themes
      per_commander = commander_cards.map { |card| CommanderThemes.call(commander: card) }

      {
        role_weights: strongest_weights(per_commander.pluck(:role_weights)),
        subtypes: per_commander.flat_map { |themes| themes[:subtypes] }.uniq,
        tribal_weight: CommanderThemes::TRIBAL_WEIGHT
      }
    end

    def strongest_weights(weight_sets)
      weight_sets.reduce({}) { |merged, weights| merged.merge(weights) { |_pair, a, b| [a, b].max } }
    end

    def scanned_roles(themes)
      return [@role] if @role

      (themes[:role_weights].keys.map(&:first) | Commanders::DeckTargets::ROLES)
    end

    def candidate_role_rows(themes)
      CardRole.high_confidence
              .where(role: scanned_roles(themes))
              .where.not(scryfall_oracle_id: excluded_oracle_ids.to_a)
              .order(:id)
              .pluck(:scryfall_oracle_id, :role, :effect, :confidence)
    end

    def excluded_oracle_ids
      deck_oracle_ids.to_set.merge(commander_cards.map(&:scryfall_oracle_id))
    end

    def deck_oracle_ids
      @deck_oracle_ids ||=
        @deck ? @deck.collection_magic_cards.joins(:magic_card).distinct.pluck('magic_cards.scryfall_oracle_id') : []
    end

    # Colour identity, format legality and the basic-land exclusion are all hard gates, and edhrec_rank is
    # needed for every survivor, so they collapse into one pass over magic_cards.
    #
    # Basics are excluded here rather than at render time: they are tagged manabase like any other land,
    # and "consider running a Forest" is not a suggestion - but dropping them late would let one occupy a
    # bucket slot and then vanish from it.
    # -> { oracle_id => edhrec_rank or nil }
    def gate(oracle_ids)
      in_identity = ColorIdentityGate.call(
        oracle_ids: oracle_ids,
        allowed_color_ids: ColorIdentityGate.color_ids_for(magic_card_ids: commander_cards.map(&:id))
      )

      MagicCard.commander_legal
               .where(scryfall_oracle_id: in_identity, card_side: [nil, 'a'])
               .where.not(name: DeckRules::Evaluators::Base::BASIC_LAND_NAMES)
               .group(:scryfall_oracle_id)
               .minimum(:edhrec_rank)
    end

    def scoring_targets(themes)
      baseline = Commanders::DeckTargets::ROLES.flat_map do |role|
        CardRole::EFFECTS.fetch(role, []).map { |effect| [[role, effect], BASELINE_WEIGHT] }
      end.to_h

      baseline.merge(themes[:role_weights])
    end

    def score(rows, themes)
      targets = scoring_targets(themes)
      scored = ConfidenceScorer.call(rows: rows, targets: targets)
      apply_tribal_bonus(scored, themes)

      scored.each_value do |data|
        data[:primary_role] = primary_role(data[:matched_roles], targets)
      end
    end

    # Tribal rides on magic_card_sub_types rather than card_roles - the role taxonomy has no concept of
    # "is a Goblin", and a commander that pays off a creature type wants those creatures regardless of
    # what else they do.
    def apply_tribal_bonus(scored, themes)
      return if themes[:subtypes].empty? || scored.empty?

      tribal = MagicCard.joins(magic_card_sub_types: :sub_type)
                        .where(scryfall_oracle_id: scored.keys, card_side: [nil, 'a'])
                        .where(sub_types: { name: themes[:subtypes] })
                        .distinct.pluck(:scryfall_oracle_id)

      tribal.each { |oracle_id| scored[oracle_id][:score] += themes[:tribal_weight] if scored.key?(oracle_id) }
    end

    def primary_role(matched_roles, targets)
      matched_roles.max_by { |match| targets.fetch([match[:role], match[:effect]], 0.0) }&.fetch(:role)
    end

    def combo_pieces
      @deck ? ComboPieces.call(deck: @deck, exclude_oracle_ids: excluded_oracle_ids) : {}
    end

    # Owned pieces only - ownership was only looked up for pieces that passed the gate, so this also
    # drops anything off-identity, illegal or basic. "This finishes a combo and it is in your binder"
    # is actionable tonight; a list
    # of combo pieces to buy is what Commander Spellbook itself is for.
    #
    # A piece takes the combo bucket over whatever role it matched - finishing a combo is the more
    # specific reason to add it - but keeps its matched roles, so the card still shows what else it does.
    # Combo count stands in for fit, which SuggestionBuckets normalises within the bucket anyway.
    def claim_combo_pieces(scored, pieces, ownership)
      pieces.slice(*ownership.keys).each do |oracle_id, combo|
        data = scored[oracle_id] ||= { score: 0.0, matched_roles: [] }
        data.merge!(score: combo[:combo_count].to_f, primary_role: COMBO_ROLE, **combo)
      end
    end

    # No MagicCard here - entries stay as plain scored data until the buckets are decided. Loading a
    # printing for every candidate meant instantiating ~10k records with their boxsets to display 96 of
    # them, which was most of the request.
    #
    # raw_fit is left unnormalised on purpose too: the confidence product is unbounded, and the scale it
    # should be measured against is the bucket it lands in, not the whole result. SuggestionBuckets does
    # the normalisation once it knows the groups.
    def build_entries(scored, ranks, ownership)
      return [] if scored.empty?

      obscurity = ObscurityScore.new
      entries = scored.map do |oracle_id, data|
        entry(oracle_id, data, ranks[oracle_id], obscurity, ownership[oracle_id])
      end

      # Two things card_roles cannot say, both read off the local precon corpus: whether designers
      # reach for this card at all, and whether it travels with what is already in the deck.
      PreconSignals.call(entries: entries, anchor_oracle_ids: deck_oracle_ids)
    end

    def entry(oracle_id, data, rank, obscurity, sources)
      {
        oracle_id: oracle_id, edhrec_rank: rank,
        raw_fit: data[:score], obscurity: obscurity.score(rank).round(3),
        matched_roles: data[:matched_roles].uniq, primary_role: data[:primary_role],
        owned: sources.present?, sources: sources || [],
        combo_count: data[:combo_count].to_i, combo_results: data[:combo_results] || []
      }
    end

    def load_ownership(oracle_ids)
      DeckBuilder::OwnershipOverlay.call(
        user: @user, oracle_ids: oracle_ids, exclude_collection_id: @deck&.id
      )
    end

    def bucket(entries, themes)
      entries = entries.select { |entry| entry[:owned] } if @owned_only

      # The ranking weights are SuggestionBuckets' own - it is the class that applies them.
      Commanders::SuggestionBuckets.call(
        entries: entries, deck_role_counts: deck_role_counts,
        roles: bucket_order(themes), per_bucket: @limit
      )
    end

    def bucket_order(themes)
      @role ? [@role] : all_roles(themes)
    end

    # Combo pieces lead when there is a deck to be one card short - completing a combo is the strongest
    # reason to add a card - then theme roles, which are what makes this commander different, with the
    # universal checklist roles behind them. Reported whole even when the result is narrowed to one role,
    # because it is also the panel's role filter and the filter has to offer the roles you are not
    # currently looking at.
    def all_roles(themes)
      theme_roles = themes[:role_weights].sort_by { |_pair, weight| -weight }.map { |pair, _weight| pair.first }.uniq
      (@deck ? [COMBO_ROLE] : []) | theme_roles | Commanders::DeckTargets::ROLES
    end

    def deck_role_counts
      return {} if deck_oracle_ids.empty?

      CardRole.high_confidence
              .where(scryfall_oracle_id: deck_oracle_ids)
              .group(:role).distinct.count(:scryfall_oracle_id)
    end
  end
end
