# Composes the analytics dashboard: resolve the scope, then build the panels asked for.
#
# The dashboard is split across requests. The shell renders the page frame and the headline numbers;
# each tab of panels below it is fetched separately. Every panel is an independent aggregate over the
# same `owned` CTE, so ten panels is ten scans of the viewer's collection - fine at a few hundred
# cards, about 720ms of SQL at twenty thousand. Splitting means the shell paints after one query and
# nobody pays for a panel they never open.
#
# SECTIONS is the whole split, and it lives here rather than in the controller for the same reason
# the panel list always has: growing the dashboard should never touch a controller. The tab bar reads
# its labels straight off it, so adding a tab is one entry.
module CollectionStats
  class Dashboard < Service
    PANELS = {
      overview: Overview,
      rarity: Rarity,
      price_tiers: PriceTiers,
      card_types: CardTypes,
      colors: Colors,
      mana_curve: ManaCurve,
      sets: Sets,
      top_cards: TopCards,
      price_movers: PriceMovers,
      roles: Roles
    }.freeze

    # Grouped by the question being asked, not by cost, but the costs came out even anyway - every
    # section is one to four queries. Panels that share a row in the layout share a section, so a
    # tab is never half a grid.
    # The partial is named here rather than interpolated from the section in the view. Same string
    # either way, but a lookup in this hash cannot be talked into rendering something else.
    SECTIONS = {
      'composition' => { label: 'Composition', partial: 'collection_stats/sections/composition',
                         panels: %i[rarity price_tiers card_types] },
      'curve' => { label: 'Colours & Curve', partial: 'collection_stats/sections/curve',
                   panels: %i[colors mana_curve] },
      'sets' => { label: 'Sets', partial: 'collection_stats/sections/sets',
                  panels: %i[sets] },
      'cards' => { label: 'Cards', partial: 'collection_stats/sections/cards',
                   panels: %i[top_cards price_movers] },
      'roles' => { label: 'Roles', partial: 'collection_stats/sections/roles',
                   panels: %i[roles] }
    }.freeze

    DEFAULT_SECTION = 'composition'.freeze

    # Overview alone. It feeds the KPI grid and both split bars, and it is the one panel the shell
    # cannot defer: show.html.erb decides between the empty state and the dashboard by reading its
    # card count.
    SHELL = %i[overview].freeze

    def self.section?(name)
      SECTIONS.key?(name.to_s)
    end

    def initialize(username:, viewer: nil, collection_id: nil, section: nil)
      @username = username
      @viewer = viewer
      @collection_id = collection_id
      @section = section
    end

    def call
      return scope if scope[:missing] || scope[:collection_ids].empty?

      scope.merge(panels)
    end

    private

    def scope
      @scope ||= Scope.call(username: @username, viewer: @viewer, collection_id: @collection_id)
    end

    # fetch, not fetch with a default: an unrecognised section is a routing mistake, and quietly
    # returning the shell would render a tab of nothing rather than say so
    def requested
      return SHELL if @section.blank?

      SECTIONS.fetch(@section.to_s)[:panels]
    end

    def panels
      ids = scope[:collection_ids]

      requested.index_with { |panel| PANELS.fetch(panel).call(collection_ids: ids) }
    end
  end
end
