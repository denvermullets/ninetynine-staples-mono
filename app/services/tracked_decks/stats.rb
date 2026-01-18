module TrackedDecks
  class Stats < Service
    def initialize(tracked_deck:)
      @tracked_deck = tracked_deck
      @games = tracked_deck.commander_games
    end

    def call
      {
        total_games: @games.count,
        wins: @games.wins.count,
        losses: @games.losses.count,
        win_rate: calculate_win_rate,
        avg_fun_rating: avg_rating(:fun_rating),
        avg_performance_rating: avg_rating(:performance_rating),
        last_played: @games.maximum(:played_on),
        games_by_bracket: games_by_bracket,
        win_rate_by_bracket: win_rate_by_bracket,
        most_common_win_condition: most_common_win_condition,
        avg_turn_ended: avg_turn_ended
      }
    end

    private

    def calculate_win_rate
      return 0.0 if @games.count.zero?

      (@games.wins.count.to_f / @games.count * 100).round(1)
    end

    def avg_rating(field)
      @games.where.not(field => nil).average(field)&.round(1)
    end

    def games_by_bracket
      @games.where.not(bracket_level: nil).group(:bracket_level).count
    end

    def win_rate_by_bracket
      (1..5).each_with_object({}) do |bracket, result|
        games = @games.by_bracket(bracket)
        next if games.count.zero?

        result[bracket] = (games.wins.count.to_f / games.count * 100).round(1)
      end
    end

    def most_common_win_condition
      @games.wins
            .where.not(win_condition: [nil, ''])
            .group(:win_condition)
            .order('count_all DESC')
            .count
            .first
    end

    def avg_turn_ended
      @games.where.not(turn_ended_on: nil).average(:turn_ended_on)&.round(1)
    end
  end
end
