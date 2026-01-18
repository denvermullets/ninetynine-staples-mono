module GameDashboard
  class OverallStats < Service
    def initialize(user:)
      @user = user
      @games = user.commander_games
      @decks = user.tracked_decks
    end

    def call
      {
        total_games: @games.count,
        total_wins: @games.wins.count,
        total_losses: @games.losses.count,
        win_rate: calculate_win_rate,
        total_decks: @decks.count,
        active_decks: @decks.active.count,
        avg_fun_rating: avg_rating(:fun_rating),
        avg_performance_rating: avg_rating(:performance_rating),
        games_this_month: games_this_month,
        games_this_year: games_this_year
      }
    end

    private

    def calculate_win_rate
      return 0.0 if @games.none?

      (@games.wins.count.to_f / @games.count * 100).round(1)
    end

    def avg_rating(field)
      @games.where.not(field => nil).average(field)&.round(1)
    end

    def games_this_month
      @games.where(played_on: Date.current.beginning_of_month..Date.current.end_of_month).count
    end

    def games_this_year
      @games.where(played_on: Date.current.beginning_of_year..Date.current.end_of_year).count
    end
  end
end
