module Decks
  # -> { collection_id => Stats }, one grouped query over the game tracker for a page of decks.
  #
  # A deck's games are those logged against any tracked deck linked to it, so a deck tracked twice
  # (say, before and after a rebuild) shows the combined record. Decks with no games are left out.
  # avg_fun is nil when games were logged but none were rated.
  class GameStats < Service
    Stats = Data.define(:games, :wins, :avg_fun, :last_played_on) do
      def win_rate = (wins.to_f / games * 100).round
    end

    def initialize(collections:)
      @collection_ids = collections.map(&:id)
    end

    def call
      return {} if @collection_ids.empty?

      rows.to_h do |collection_id, games, wins, avg_fun, last_played_on|
        [collection_id, Stats.new(games: games, wins: wins, avg_fun: avg_fun&.to_f&.round(1),
                                  last_played_on: last_played_on)]
      end
    end

    private

    def rows
      CommanderGame
        .joins(:tracked_deck)
        .where(tracked_decks: { collection_id: @collection_ids })
        .group('tracked_decks.collection_id')
        .pluck(Arel.sql('tracked_decks.collection_id'), Arel.sql('COUNT(*)'),
               Arel.sql('COUNT(*) FILTER (WHERE commander_games.won)'),
               Arel.sql('AVG(commander_games.fun_rating)'),
               Arel.sql('MAX(commander_games.played_on)'))
    end
  end
end
