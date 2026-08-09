#
# resolves the collection view's display mode from params
#
# Deliberately knows nothing about the card relation: the caller paginates first and derives the
# visual-mode data from that page. This used to build the aggregates and groupings itself, off the
# unpaginated relation, which loaded every owned card to render 50.
#
module Collections
  class ViewMode < Service
    def initialize(params:)
      @view_mode = params[:view_mode] || 'table'
      @grouping = params[:grouping] || 'none'
      @grouping_allowed = params[:code].present?
    end

    def call
      { view_mode: @view_mode, grouping: @grouping, grouping_allowed: @grouping_allowed }
    end

    def visual? = @view_mode == 'visual'

    attr_reader :view_mode, :grouping, :grouping_allowed
  end
end
