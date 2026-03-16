module Admin
  class DeckRulesController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_admin
    before_action :set_deck_rule, only: %i[edit update destroy]

    def index
      @deck_rules = DeckRule
                    .includes(:bracket)
                    .joins('LEFT JOIN brackets ON brackets.id = deck_rules.bracket_id')
                    .order(Arel.sql('brackets.level IS NOT NULL, brackets.level, deck_rules.rule_type'))
    end

    def new
      @deck_rule = DeckRule.new
    end

    def create
      @deck_rule = DeckRule.new(deck_rule_params)
      if @deck_rule.save
        redirect_to admin_deck_rules_path, notice: 'Deck rule created successfully.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @deck_rule.update(deck_rule_params)
        redirect_to admin_deck_rules_path, notice: 'Deck rule updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @deck_rule.destroy
      redirect_to admin_deck_rules_path, notice: 'Deck rule deleted successfully.'
    end

    private

    def set_deck_rule
      @deck_rule = DeckRule.find(params[:id])
    end

    def ensure_admin
      redirect_to(root_path, alert: 'Access denied') unless current_user&.role.to_i == 9001
    end

    def deck_rule_params
      params.require(:deck_rule).permit(:name, :description, :rule_type, :value, :bracket_id, :applies_to, :enabled)
    end
  end
end
