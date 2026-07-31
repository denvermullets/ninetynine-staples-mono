#
# sort state for the clickable column headings on the collections table
#
module CollectionSorting
  extend ActiveSupport::Concern

  # owned_price is a pseudo column with no header of its own - it's the default that keeps
  # the table ordered by the highest price of the finishes actually owned.
  SORT_COLUMNS = %w[
    owned_price card_number name card_type mana_value normal_price foil_price
    ck_buylist_normal_price ck_buylist_foil_price edhrec_saltiness
  ].freeze

  # SortConfig builds the header links from only these keys, so anything left out gets
  # dropped when a heading is clicked. page is excluded on purpose - sorting starts over
  # from the first page.
  PRESERVE_PARAMS = %i[
    username collection_id collection_type code search rarity mana
    view_mode grouping hide_proxies exact_color_match price_change_range
  ].freeze

  included do
    helper_method :sort_config
  end

  private

  # reorders the grouped relation Search::Collection returns to match the clicked heading
  def apply_sort(cards)
    CollectionQuery::CollectionSort.call(
      cards: cards, column: sort_config.column, direction: sort_config.direction
    )
  end

  def sort_config
    @sort_config ||= CollectionQuery::SortConfig.new(
      params: params,
      allowed_columns: SORT_COLUMNS,
      default_column: CollectionQuery::CollectionSort::DEFAULT_COLUMN,
      preserve_params: PRESERVE_PARAMS
    )
  end
end
