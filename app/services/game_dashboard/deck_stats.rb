module GameDashboard
  class DeckStats < Service
    def initialize(user:)
      @user = user
      @decks = user.tracked_decks.includes(:commander, :partner_commander, :commander_games)
    end

    def call
      @decks.map do |deck|
        {
          id: deck.id,
          name: deck.name,
          commander_name: deck.commander_display_name,
          commander_image: deck.commander.image_small,
          status: deck.status,
          status_badge_class: deck.status_badge_class,
          games_count: deck.games_count,
          wins: deck.wins_count,
          losses: deck.losses_count,
          win_rate: deck.win_rate,
          avg_fun_rating: deck.avg_fun_rating,
          avg_performance_rating: deck.avg_performance_rating,
          last_played: deck.last_played_on
        }
      end.sort_by { |d| [-d[:games_count], d[:name]] }
    end
  end
end
