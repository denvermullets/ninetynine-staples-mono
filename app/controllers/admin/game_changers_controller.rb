module Admin
  class GameChangersController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_admin
    before_action :set_game_changer, only: %i[edit update destroy]

    def index
      @game_changers = GameChanger.alphabetical
    end

    def new
      @game_changer = GameChanger.new
    end

    def create
      @game_changer = GameChanger.new(game_changer_params)
      if @game_changer.save
        redirect_to admin_game_changers_path, notice: 'Game changer created successfully.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @game_changer.update(game_changer_params)
        redirect_to admin_game_changers_path, notice: 'Game changer updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @game_changer.destroy
      redirect_to admin_game_changers_path, notice: 'Game changer deleted successfully.'
    end

    def search_cards
      query = params[:q].to_s.strip
      return render json: [] if query.length < 2

      cards = MagicCard
              .where('name ILIKE ?', "%#{MagicCard.sanitize_sql_like(query)}%")
              .where.not(scryfall_oracle_id: nil)
              .select('DISTINCT ON (scryfall_oracle_id) id, name, scryfall_oracle_id')
              .order(:scryfall_oracle_id, :name)
              .limit(10)

      render json: cards.map { |c| { id: c.id, name: c.name, oracle_id: c.scryfall_oracle_id } }
    end

    private

    def set_game_changer
      @game_changer = GameChanger.find(params[:id])
    end

    def ensure_admin
      redirect_to(root_path, alert: 'Access denied') unless current_user&.role.to_i == 9001
    end

    def game_changer_params
      params.require(:game_changer).permit(:oracle_id, :card_name, :reason)
    end
  end
end
