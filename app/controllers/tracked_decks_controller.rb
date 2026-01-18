class TrackedDecksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_tracked_deck, only: %i[show edit update destroy]
  before_action :ensure_owner, only: %i[show edit update destroy]

  def index
    @tracked_decks = current_user.tracked_decks
                                 .includes(:commander, :partner_commander, :commander_games)
                                 .order(created_at: :desc)
  end

  def show
    @stats = TrackedDecks::Stats.call(tracked_deck: @tracked_deck)
    @recent_games = @tracked_deck.commander_games.recent.limit(10)
  end

  def new
    @tracked_deck = current_user.tracked_decks.build
  end

  def create
    @tracked_deck = current_user.tracked_decks.build(tracked_deck_params)

    if @tracked_deck.save
      redirect_to @tracked_deck, notice: 'Deck tracking started!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @tracked_deck.update(tracked_deck_params)
      redirect_to @tracked_deck, notice: 'Deck updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tracked_deck.destroy
    redirect_to tracked_decks_path, notice: 'Deck tracking removed.', status: :see_other
  end

  def search_commanders
    @commanders = CommanderGames::SearchCommanders.call(query: params[:q])
    render partial: 'commander_results', locals: { commanders: @commanders }
  end

  private

  def set_tracked_deck
    @tracked_deck = TrackedDeck.find(params[:id])
  end

  def ensure_owner
    redirect_to tracked_decks_path, alert: 'Access denied' unless @tracked_deck.user_id == current_user.id
  end

  def tracked_deck_params
    params.require(:tracked_deck).permit(
      :name, :commander_id, :partner_commander_id, :notes,
      :status, :last_tweaked_at
    )
  end
end
