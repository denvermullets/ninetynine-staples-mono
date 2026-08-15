module Commanders
  # "What weird deck could I build today with zero purchases?"
  #
  # Five queries, regardless of how many commanders come back: the candidate list, the two behind
  # ThemeProfiles, the collection profile, and the tribal counts. Everything after that is Ruby over
  # a fixed universe of ~3,235 commanders, and the page's 50 rows are hydrated into MagicCard records
  # by the caller afterwards.
  #
  # Entries stay as plain scored tuples until the page is decided, for the reason
  # CardAnalysis::CommanderSynergy gives: instantiating a printing and its boxset for every candidate
  # in order to display 50 of them is most of the request.
  class Discovery < Service
    SORTS = %w[buildable hipster rank mana_value].freeze

    # Bands are cut where CardAnalysis::ObscurityScore's curve turns, not on round numbers: it peaks
    # around rank 2,500 with the useful shoulder running roughly 800-8,000, so "known" is the band
    # that scores well and "obscure" is where cards start being unplayed because they are bad.
    # nil rank is its own bucket - unranked means too new for anyone to have an opinion, not obscure.
    RANK_BANDS = { 'all' => nil, 'staples' => (1..800), 'known' => (801..8000),
                   'obscure' => (8001..) }.freeze

    EMPTY_THEME = { role_weights: {}, subtypes: [] }.freeze

    # How far completeness may move an already-fitting commander, as a multiplier around 1.0. At 0.8
    # it swings the score between 0.6x and 1.4x.
    #
    # A MULTIPLIER CENTRED ON NEUTRAL, NOT A PRODUCT - the same shape SuggestionBuckets uses on
    # obscurity, and for the same reason. fit * completeness reads as "fit leads, completeness scales
    # it", but completeness is zero for any collection thin on the generic checklist roles, and zero
    # times anything is zero: two commanders in the same colours would come out tied at 0 however
    # differently the collection served them, and the list would fall through to alphabetical order.
    # Centred, completeness cuts and boosts but cannot annihilate the axis it is modifying.
    COMPLETENESS_WEIGHT = 0.8

    NEUTRAL = 0.5

    # rubocop:disable Metrics/ParameterLists -- each is a real axis of the page's filter bar and
    # collapsing them into an options hash would only hide that from the controller.
    def initialize(collection_ids:, sort: 'buildable', band: 'all', colors: nil, code: nil,
                   owned_only: false, min_completeness: 0.0)
      @collection_ids = Array(collection_ids).compact
      @sort = SORTS.include?(sort) ? sort : 'buildable'
      @band = RANK_BANDS.key?(band) ? band : 'all'
      @colors = colors
      @code = code.presence
      @owned_only = owned_only
      @min_completeness = min_completeness.to_f
    end
    # rubocop:enable Metrics/ParameterLists

    # -> { rows: [scored entries, sorted], total:, matched: }
    def call
      entries = score(candidates)
      kept = entries.select { |entry| entry[:completeness] >= @min_completeness }

      { rows: sort(kept), total: entries.size, matched: kept.size }
    end

    private

    def candidates
      @candidates ||= Candidates.call(band: RANK_BANDS[@band], colors: @colors, code: @code,
                                      owned_collection_ids: @owned_only ? @collection_ids : nil)
    end

    def profile
      @profile ||= CollectionStats::BuildableProfile.call(collection_ids: @collection_ids)
    end

    # Buildability is a property of the mask, not of the commander, so it is computed once per
    # distinct identity - at most 32 times, never 3,235.
    def buildability(mask)
      @buildability ||= {}
      @buildability[mask] ||= Buildability.call(profile: profile, mask: mask)
    end

    def themes
      @themes ||= ThemeProfiles.call(commanders: candidates.map { |row| [row[:oracle_id], row[:text]] })
    end

    # Only the types a candidate actually names, so the aggregate stays small.
    def tribes
      @tribes ||= CollectionStats::BuildableTribes.call(
        collection_ids: @collection_ids, subtypes: themes.values.flat_map { |theme| theme[:subtypes] }
      )
    end

    def tribe_counts(mask)
      @tribe_counts ||= {}
      @tribe_counts[mask] ||= ColorMask.submasks(mask).each_with_object(Hash.new(0)) do |submask, totals|
        tribes.fetch(submask, {}).each { |name, count| totals[name] += count }
      end
    end

    def score(rows)
      obscurity = CardAnalysis::ObscurityScore.new

      rows.map { |row| entry(row, obscurity) }
    end

    def entry(row, obscurity)
      build = buildability(row[:mask])

      row.merge(build.slice(:owned_pool, :role_coverage, :completeness, :bottleneck))
         .merge(fit_for(row, build))
         .merge(obscurity: obscurity.score(row[:edhrec_rank]).round(3))
    end

    def fit_for(row, build)
      theme = themes.fetch(row[:oracle_id], EMPTY_THEME)
      fit = ThemeFit.call(role_weights: theme[:role_weights], subtypes: theme[:subtypes],
                          effect_counts: build[:effect_counts], tribe_counts: tribe_counts(row[:mask]))

      { fit: fit[:score], themed: fit[:themed], matched: fit[:matched] }
    end

    # Fit leads and completeness modulates it: a commander whose themes you are deep in is the point,
    # but it still has to be a deck you can fill out. Hipster multiplies the obscurity band in on top,
    # which is what stops the list being the same twelve precon faces every time - and there the raw
    # band is right rather than a centred multiplier, because burying the format's staples is the
    # entire job of that sort.
    #
    # `buildable` breaks its ties on obscurity rather than on rank, because ~5% of the format
    # saturates fit at exactly 1.0 and something has to order them. Ranking those by edhrec_rank
    # ascending put every unranked card first - which is Universes Beyond crossovers and joke
    # commanders, since nobody has an opinion on them yet. ObscurityScore already scores a nil rank
    # at NEUTRAL, so they land mid-pack instead of leading the page.
    def sort(entries)
      entries.sort_by { |entry| sort_key(entry) }
    end

    def sort_key(entry)
      case @sort
      when 'hipster' then [-(blend(entry) * entry[:obscurity]), entry[:name]]
      when 'rank' then [entry[:edhrec_rank] || Float::INFINITY, entry[:name]]
      when 'mana_value' then [entry[:mana_value] || 0, entry[:name]]
      else [-blend(entry), -entry[:obscurity], entry[:name]]
      end
    end

    def blend(entry)
      entry[:fit] * (1 + (COMPLETENESS_WEIGHT * (entry[:completeness] - NEUTRAL)))
    end
  end
end
