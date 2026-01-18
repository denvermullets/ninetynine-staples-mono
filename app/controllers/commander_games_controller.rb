class CommanderGamesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_commander_game, only: %i[show edit update destroy]
  before_action :ensure_owner, only: %i[show edit update destroy]

  def index
    games = current_user.commander_games
                        .includes(tracked_deck: %i[commander partner_commander])
                        .recent
    @pagy, @games = pagy(games, items: 20)
  end

  def show
    @opponents = @commander_game.game_opponents.includes(:commander, :partner_commander)
  end

  def new
    @commander_game = current_user.commander_games.build(played_on: Date.current)
    @tracked_decks = current_user.tracked_decks.active.includes(:commander)
    3.times { @commander_game.game_opponents.build }
  end

  def create
    @commander_game = current_user.commander_games.build(commander_game_params)

    if @commander_game.save
      redirect_to @commander_game, notice: 'Game recorded!'
    else
      @tracked_decks = current_user.tracked_decks.active.includes(:commander)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @tracked_decks = current_user.tracked_decks.includes(:commander)
    @commander_game.game_opponents.build while @commander_game.game_opponents.size < 3
  end

  def update
    if @commander_game.update(commander_game_params)
      redirect_to @commander_game, notice: 'Game updated successfully.'
    else
      @tracked_decks = current_user.tracked_decks.includes(:commander)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @commander_game.destroy
    redirect_to commander_games_path, notice: 'Game removed.', status: :see_other
  end

  def search_opponents
    @commanders = CommanderGames::SearchCommanders.call(query: params[:q])
    render partial: 'opponent_results', locals: { commanders: @commanders, index: params[:index].to_i }
  end

  private

  def set_commander_game
    @commander_game = CommanderGame.find(params[:id])
  end

  def ensure_owner
    redirect_to commander_games_path, alert: 'Access denied' unless @commander_game.user_id == current_user.id
  end

  def commander_game_params
    params.require(:commander_game).permit(
      :tracked_deck_id, :played_on, :won, :turn_ended_on, :pod_size,
      :bracket_level, :fun_rating, :performance_rating,
      :win_condition, :how_won, :notes,
      game_opponents_attributes: %i[
        id commander_id partner_commander_id won win_condition how_won _destroy
      ]
    )
  end
end
