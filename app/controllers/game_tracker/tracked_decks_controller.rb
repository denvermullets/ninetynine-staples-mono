module GameTracker
  class TrackedDecksController < BaseController
    before_action :authenticate_user!, only: %i[new create edit update destroy search_commanders]
    before_action :set_tracked_deck, only: %i[show edit update destroy]
    before_action :ensure_owner, only: %i[edit update destroy]

    def index
      @is_owner = viewing_own_tracker?
      @tracked_decks = tracker_owner.tracked_decks
                                    .includes(:commander, :partner_commander, :commander_games)
                                    .order(created_at: :desc)
    end

    def show
      @is_owner = viewing_own_tracker?
      @stats = TrackedDecks::Stats.call(tracked_deck: @tracked_deck)
      @recent_games = @tracked_deck.commander_games.recent.limit(10)
    end

    def new
      @tracked_deck = current_user.tracked_decks.build
    end

    def create
      @tracked_deck = current_user.tracked_decks.build(tracked_deck_params)

      if @tracked_deck.save
        redirect_to game_tracker_tracked_deck_path(current_user.username, @tracked_deck),
                    notice: 'Deck tracking started!'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @tracked_deck.update(tracked_deck_params)
        redirect_to game_tracker_tracked_deck_path(current_user.username, @tracked_deck),
                    notice: 'Deck updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @tracked_deck.destroy
      redirect_to game_tracker_tracked_decks_path(current_user.username), notice: 'Deck tracking removed.',
                                                                          status: :see_other
    end

    def search_commanders
      @commanders = CommanderGames::SearchCommanders.call(query: params[:q])
      render partial: 'commander_results', locals: { commanders: @commanders }
    end

    private

    def set_tracked_deck
      @tracked_deck = TrackedDeck.find(params[:id])
      # For username-scoped routes, ensure the deck belongs to the user in the URL
      return unless username_scoped_route? && @tracked_deck.user_id != tracker_owner.id

      redirect_to root_path, alert: 'Deck not found'
    end

    def ensure_owner
      return if logged_in? && @tracked_deck.user_id == current_user.id

      redirect_to root_path, alert: 'Access denied'
    end

    def tracked_deck_params
      params.require(:tracked_deck).permit(
        :name, :commander_id, :partner_commander_id, :notes,
        :status, :last_tweaked_at
      )
    end
  end
end
