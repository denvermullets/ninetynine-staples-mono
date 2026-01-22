class GameTrackerController < GameTracker::BaseController
  def show
    @is_owner = viewing_own_tracker?
    @overall_stats = GameDashboard::OverallStats.call(user: tracker_owner)
    @deck_stats = GameDashboard::DeckStats.call(user: tracker_owner)
    @bracket_stats = GameDashboard::BracketStats.call(user: tracker_owner)
    @opponent_stats = GameDashboard::OpponentStats.call(user: tracker_owner)
    @recent_games = tracker_owner.commander_games
                                 .includes(tracked_deck: %i[commander partner_commander])
                                 .recent
                                 .limit(5)
  end
end
