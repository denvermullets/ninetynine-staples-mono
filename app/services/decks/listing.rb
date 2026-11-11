module Decks
  # -> Result for the decks index: the user's decks as the viewer may see them, sorted and grouped.
  # Built here rather than in the controller so a turbo stream response (a deck edited or deleted from
  # the index) can redraw the grid with the same sort and grouping the page was showing.
  #
  # exclude_id drops one deck that is on its way out: deletion runs in a job, so the row still exists
  # when the response that has to hide it is rendered.
  #
  # Game tracker stats ride along only when the viewer may see that user's tracker (their own, or one
  # made public); otherwise game_stats is empty and the sorts built on it aren't offered. Those sorts
  # run in Ruby over the loaded page: decks with no data keep recently-updated order at the end.
  class Listing < Service
    SORT_OPTIONS = {
      'updated_desc' => { label: 'Recently Updated', order: { updated_at: :desc } },
      'building' => { label: 'Building', order: nil },
      'created_desc' => { label: 'Newest First', order: { created_at: :desc } },
      'created_asc' => { label: 'Oldest First', order: { created_at: :asc } },
      'name_asc' => { label: 'Name (A-Z)', order: { name: :asc } },
      'name_desc' => { label: 'Name (Z-A)', order: { name: :desc } },
      'value_desc' => { label: 'Value (High-Low)', order: { total_value: :desc } },
      'value_asc' => { label: 'Value (Low-High)', order: { total_value: :asc } }
    }.freeze

    GAME_SORT_OPTIONS = {
      'win_rate_desc' => { label: 'Win Rate', order: { updated_at: :desc } },
      'fun_desc' => { label: 'Fun Rating', order: { updated_at: :desc } }
    }.freeze

    GAME_METRICS = { 'win_rate_desc' => :win_rate, 'fun_desc' => :avg_fun }.freeze

    BUILDING_SELECT_SQL = <<~SQL.squish
      collections.*,
      EXISTS(
        SELECT 1 FROM collection_magic_cards
        WHERE collection_magic_cards.collection_id = collections.id
        AND collection_magic_cards.staged = true
      ) AS is_building
    SQL

    Result = Data.define(:user, :is_owner, :sort, :sort_options, :group_by, :decks, :color_identities,
                         :game_stats, :groups)

    def initialize(user:, viewer:, sort: nil, group_by: nil, exclude_id: nil)
      @user = user
      @is_owner = viewer&.id == user.id
      @show_games = @is_owner || user.game_tracker_public?
      @sort_options = @show_games ? SORT_OPTIONS.merge(GAME_SORT_OPTIONS) : SORT_OPTIONS
      @sort = sort.presence_in(@sort_options.keys) || 'updated_desc'
      @group_by = group_by.presence_in(Grouping::OPTIONS.keys) || 'none'
      @exclude_id = exclude_id
    end

    def call
      decks = sorted(visible).to_a
      game_stats = @show_games ? GameStats.call(collections: decks) : {}
      decks = sorted_by_games(decks, game_stats)
      color_identities = Collections::ColorIdentities.call(collections: decks)
      groups = Grouping.call(decks: decks, by: @group_by, color_identities: color_identities)

      Result.new(user: @user, is_owner: @is_owner, sort: @sort, sort_options: @sort_options,
                 group_by: @group_by, decks: decks, color_identities: color_identities,
                 game_stats: game_stats, groups: groups)
    end

    private

    def visible
      decks = @user.collections.decks.includes(:tags)
      decks = decks.where.not(id: @exclude_id) if @exclude_id
      @is_owner ? decks : decks.visible_to_public
    end

    def sorted(decks)
      return decks.order(@sort_options[@sort][:order]) unless @sort == 'building'

      decks.left_joins(:collection_magic_cards)
           .select(BUILDING_SELECT_SQL)
           .group('collections.id')
           .order(Arel.sql('is_building DESC, collections.updated_at DESC'))
    end

    # ties on the metric go to the deck with more games behind it; sort_by isn't stable, so the
    # incoming position is the last tiebreak
    def sorted_by_games(decks, game_stats)
      metric = GAME_METRICS[@sort]
      return decks unless metric

      value = ->(deck) { game_stats[deck.id]&.public_send(metric) }
      rated, unrated = decks.partition(&value)
      rated.each_with_index
           .sort_by { |deck, i| [-value.call(deck), -game_stats[deck.id].games, i] }
           .map(&:first) + unrated
    end
  end
end
