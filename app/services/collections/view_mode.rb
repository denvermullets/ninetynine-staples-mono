module Collections
  class ViewMode < Service
    def initialize(filtered_cards:, user:, params:)
      @filtered_cards = filtered_cards
      @user = user
      @view_mode = params[:view_mode] || 'table'
      @grouping = params[:grouping] || 'none'
      @grouping_allowed = params[:code].present?
    end

    def call
      result = { view_mode: @view_mode, grouping: @grouping, grouping_allowed: @grouping_allowed }

      unless @filtered_cards.present?
        return result.merge(magic_cards: [], pagy: nil, aggregated_quantities: nil, grouped_cards: nil)
      end

      cards = @filtered_cards
      visual = visual_data

      result.merge(magic_cards: cards, aggregated_quantities: visual&.dig(:aggregated_quantities),
                   grouped_cards: visual&.dig(:grouped_cards))
    end

    def skip_pagination?
      @view_mode == 'visual' && @grouping != 'none' && @grouping_allowed
    end

    attr_reader :filtered_cards, :view_mode

    private

    def visual_data
      return nil unless @view_mode == 'visual'

      Collections::VisualModeSetup.call(cards: @filtered_cards, user: @user, grouping: @grouping)
    end
  end
end
