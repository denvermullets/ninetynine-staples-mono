# Matchmaking between want lists and the copies sitting in public collections, grouped by the user on
# the other side.
#
# :forward is "who has my wants": this user's want list against everyone else's public collections.
# A holder appears whether or not the copy is marked for trade - owning it is enough to be worth a
# message - but marked copies rank first, and only a holder with a public trade list has marks to
# rank on. Marked copies already promised to an accepted trade are not on offer either: they count as
# pending rather than tradeable until that trade completes or falls through (WantList::MatchSql).
#
# :inverse is "who wants what I'm trading": this user's marked copies against every public want
# list. Everything in it is tradeable by construction, so tradeable_count and total_count agree.
#
# `with:` narrows either direction to one counterpart, which is what a badge on somebody's trade list
# or a pre-seeded trade builder needs.
#
# The match rule lives in WantList::MatchSql. One match is one want met by one printing, summed over
# the holder's public collections; an any-printing want met by two printings is two matches and one
# want, and the counts are of wants.
#
# Users are ranked by wants they could trade for, then wants matched at all, then username, and paged
# here rather than by the caller: the ranking is an aggregate over the whole join, so the cheap part
# is loading rows for the twenty users on the page instead of for everybody. `total` is the number of
# matched users, for Pagy.new(count:).
module WantList
  class Matches < Service
    DIRECTIONS = %i[forward inverse].freeze
    PER_PAGE = 20

    UserMatches = Data.define(:user, :matches, :tradeable_count, :total_count)
    Match = Data.define(:want, :printing, :tradeable, :quantity, :foil_quantity,
                        :trade_quantity, :trade_foil_quantity, :pending_quantity, :pending_foil_quantity) do
      # marked for trade, but every marked copy is sitting in an accepted trade
      def pending?
        !tradeable && (pending_quantity + pending_foil_quantity).positive?
      end
    end

    # which side of a pair is the user asking, and which is the one they are shown
    SIDES = {
      forward: { mine: 'wants.user_id', other: 'collections.user_id', theirs: 'holder_id' },
      inverse: { mine: 'collections.user_id', other: 'wants.user_id', theirs: 'wanter_id' }
    }.freeze

    # a private want list is nobody's business, and an unmarked copy is not on offer
    INVERSE_ONLY = <<~SQL.squish.freeze
      AND (#{MatchSql::TRADE_QUANTITY}) + (#{MatchSql::TRADE_FOIL_QUANTITY}) > 0
      AND EXISTS (SELECT 1 FROM users wanters WHERE wanters.id = wants.user_id AND wanters.wants_public = TRUE)
    SQL

    COUNTS = %w[quantity foil_quantity trade_quantity trade_foil_quantity
                pending_quantity pending_foil_quantity].freeze

    TRADEABLE = 'trade_quantity + trade_foil_quantity > 0'.freeze

    def initialize(user:, direction: :forward, with: nil, page: 1, per_page: PER_PAGE)
      raise ArgumentError, "unknown direction: #{direction.inspect}" unless DIRECTIONS.include?(direction)

      @user = user
      @direction = direction
      @with = with
      @page = [page.to_i, 1].max
      @per_page = per_page.to_i.clamp(1, 100)
    end

    def call
      return { users: [], total: 0 } if @user.nil?

      { users: ranked.map { |row| user_matches(row) }, total: ranked.first&.fetch('total').to_i }
    end

    private

    def sides
      SIDES[@direction]
    end

    def pairs
      @pairs ||= MatchSql.pairs(conditions, viewer_id: @user.id)
    end

    def conditions
      sql = ["AND #{sides[:mine]} = #{@user.id.to_i}"]
      sql << format(INVERSE_ONLY, viewer_id: @user.id) if @direction == :inverse
      sql << "AND #{sides[:other]} = #{@with.id.to_i}" if @with
      sql.join(' ')
    end

    # the page of counterparts, best first, each with its counts and the size of the whole ranking
    def ranked
      @ranked ||= select_all(<<~SQL.squish)
        #{pairs}
        SELECT pairs.#{sides[:theirs]} AS user_id,
               COUNT(DISTINCT pairs.want_id) AS total_count,
               COUNT(DISTINCT pairs.want_id) FILTER (WHERE #{TRADEABLE}) AS tradeable_count,
               COUNT(*) OVER () AS total
        FROM pairs
        INNER JOIN users ON users.id = pairs.#{sides[:theirs]}
        GROUP BY pairs.#{sides[:theirs]}, users.username
        ORDER BY tradeable_count DESC, total_count DESC, LOWER(users.username) ASC, user_id ASC
        LIMIT #{@per_page} OFFSET #{(@page - 1) * @per_page}
      SQL
    end

    # one row per counterpart per want per printing, for the counterparts on this page only
    def match_rows
      @match_rows ||= begin
        ids = ranked.map { |row| row['user_id'].to_i }
        ids.empty? ? [] : select_all(<<~SQL.squish)
          #{pairs}
          SELECT pairs.#{sides[:theirs]} AS user_id, pairs.want_id, pairs.printing_id,
                 SUM(quantity) AS quantity, SUM(foil_quantity) AS foil_quantity,
                 SUM(trade_quantity) AS trade_quantity, SUM(trade_foil_quantity) AS trade_foil_quantity,
                 SUM(pending_quantity) AS pending_quantity, SUM(pending_foil_quantity) AS pending_foil_quantity
          FROM pairs
          WHERE pairs.#{sides[:theirs]} IN (#{ids.join(', ')})
          GROUP BY pairs.#{sides[:theirs]}, pairs.want_id, pairs.printing_id
        SQL
      end
    end

    def select_all(sql)
      ActiveRecord::Base.connection.select_all(sql).to_a
    end

    def user_matches(row)
      user_id = row['user_id'].to_i
      matches = rows_by_user.fetch(user_id, []).map { |match_row| match(match_row) }

      UserMatches.new(user: users[user_id], matches: sorted(matches),
                      tradeable_count: row['tradeable_count'].to_i, total_count: row['total_count'].to_i)
    end

    def match(row)
      counts = COUNTS.to_h { |column| [column.to_sym, row[column].to_i] }

      Match.new(want: wants[row['want_id'].to_i], printing: printings[row['printing_id'].to_i],
                tradeable: (counts[:trade_quantity] + counts[:trade_foil_quantity]).positive?, **counts)
    end

    # tradeable first inside a user too, then the order a want list is read in
    def sorted(matches)
      matches.sort_by { |match| [match.tradeable ? 0 : 1, match.printing.name.to_s.downcase, match.printing.id] }
    end

    def rows_by_user
      @rows_by_user ||= match_rows.group_by { |row| row['user_id'].to_i }
    end

    def users
      @users ||= User.where(id: rows_by_user.keys).index_by(&:id)
    end

    def wants
      @wants ||= WantListItem.where(id: match_rows.map { |row| row['want_id'] }.uniq).index_by(&:id)
    end

    def printings
      @printings ||= MagicCard.includes(:boxset)
                              .where(id: match_rows.map { |row| row['printing_id'] }.uniq).index_by(&:id)
    end
  end
end
