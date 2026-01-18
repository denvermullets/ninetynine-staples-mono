class GameDashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @overall_stats = GameDashboard::OverallStats.call(user: current_user)
    @deck_stats = GameDashboard::DeckStats.call(user: current_user)
    @bracket_stats = GameDashboard::BracketStats.call(user: current_user)
    @opponent_stats = GameDashboard::OpponentStats.call(user: current_user)
    @recent_games = current_user.commander_games
                                .includes(tracked_deck: [:commander, :partner_commander])
                                .recent
                                .limit(5)
  end
end
