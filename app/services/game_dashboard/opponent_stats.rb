module GameDashboard
  class OpponentStats < Service
    def initialize(user:)
      @user = user
      @games = user.commander_games
    end

    def call
      {
        commanders_that_beat_you: commanders_that_beat_you,
        win_conditions_against_you: win_conditions_against_you,
        most_faced_commanders: most_faced_commanders
      }
    end

    private

    def commanders_that_beat_you
      GameOpponent
        .joins(:commander_game)
        .where(commander_games: { user_id: @user.id })
        .where(won: true)
        .joins(:commander)
        .group('magic_cards.name')
        .order('count_all DESC')
        .limit(10)
        .count
        .map { |name, count| { commander_name: name, losses: count } }
    end

    def win_conditions_against_you
      GameOpponent
        .joins(:commander_game)
        .where(commander_games: { user_id: @user.id })
        .where(won: true)
        .where.not(win_condition: [nil, ''])
        .group(:win_condition)
        .order('count_all DESC')
        .count
        .map { |condition, count| { win_condition: condition, losses: count } }
    end

    def most_faced_commanders
      GameOpponent
        .joins(:commander_game)
        .where(commander_games: { user_id: @user.id })
        .joins(:commander)
        .group('magic_cards.name')
        .order('count_all DESC')
        .limit(10)
        .count
        .map { |name, count| { commander_name: name, games: count } }
    end
  end
end
