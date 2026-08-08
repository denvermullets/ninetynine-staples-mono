module Collections
  class ViewMode < Service
    def initialize(filtered_cards:, user:, params:, total_count:)
      @filtered_cards = filtered_cards
      @user = user
      @view_mode = params[:view_mode] || 'table'
      @grouping = params[:grouping] || 'none'
      @grouping_allowed = params[:code].present?
      @total_count = total_count
    end

    def call
      result = { view_mode: @view_mode, grouping: @grouping, grouping_allowed: @grouping_allowed }

      # the caller already counted the relation to hand pagy an explicit count, so reuse it rather
      # than asking the database again - this used to be an exists? on the same grouped relation
      if @total_count.zero?
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

    attr_reader :filtered_cards, :view_mode, :total_count

    private

    def visual_data
      return nil unless @view_mode == 'visual'

      Collections::VisualModeSetup.call(cards: @filtered_cards, user: @user, grouping: @grouping)
    end
  end
end
