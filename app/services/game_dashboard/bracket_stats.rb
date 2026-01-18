module GameDashboard
  class BracketStats < Service
    def initialize(user:)
      @user = user
      @games = user.commander_games.where.not(bracket_level: nil)
    end

    def call
      (1..5).map do |bracket|
        games = @games.by_bracket(bracket)
        wins = games.wins.count
        total = games.count

        {
          bracket: bracket,
          total_games: total,
          wins: wins,
          losses: total - wins,
          win_rate: total.zero? ? 0.0 : (wins.to_f / total * 100).round(1)
        }
      end
    end
  end
end
