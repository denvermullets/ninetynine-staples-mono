module Admin
  class BracketsController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_admin
    before_action :set_bracket, only: %i[edit update destroy]

    def index
      @brackets = Bracket.ordered.includes(:deck_rules)
    end

    def new
      @bracket = Bracket.new
    end

    def create
      @bracket = Bracket.new(bracket_params)
      if @bracket.save
        redirect_to admin_brackets_path, notice: 'Bracket created successfully.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @bracket.update(bracket_params)
        redirect_to admin_brackets_path, notice: 'Bracket updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @bracket.destroy
      redirect_to admin_brackets_path, notice: 'Bracket deleted successfully.'
    end

    private

    def set_bracket
      @bracket = Bracket.find(params[:id])
    end

    def ensure_admin
      redirect_to(root_path, alert: 'Access denied') unless current_user&.role.to_i == 9001
    end

    def bracket_params
      params.require(:bracket).permit(:level, :name, :description, :enabled)
    end
  end
end
