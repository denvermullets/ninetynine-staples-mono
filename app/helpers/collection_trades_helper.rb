# Pricing for the trade list rows. The rows are MagicCard records hydrated by CollectionQuery::PageRows,
# carrying trade_quantity / trade_foil_quantity summed across the owner's public collections.
module CollectionTradesHelper
  PRICE_COLUMNS = {
    retail: %i[normal_price foil_price],
    buylist: %i[ck_buylist_normal_price ck_buylist_foil_price]
  }.freeze

  # every copy on offer priced at its own finish - the per-row half of CollectionTrades::List#totals
  def trade_row_value(card, source = :retail)
    regular_column, foil_column = PRICE_COLUMNS.fetch(source)

    (card.trade_quantity.to_i * card[regular_column].to_d) +
      (card.trade_foil_quantity.to_i * card[foil_column].to_d)
  end

  # the unit prices for the finishes actually on offer, so a foil-only row never shows a regular price
  def trade_unit_prices(card, source = :retail)
    regular_column, foil_column = PRICE_COLUMNS.fetch(source)
    parts = []
    parts << number_to_currency(card[regular_column].to_d) if card.trade_quantity.to_i.positive?
    parts << "#{number_to_currency(card[foil_column].to_d)} foil" if card.trade_foil_quantity.to_i.positive?
    parts.join(' / ')
  end

  def trade_finish_text(finish)
    case finish
    when 'regular' then 'Printings with at least one non-foil copy on offer.'
    when 'foil' then 'Printings with at least one foil copy on offer.'
    else 'Every printing on offer, one row each, summed across public collections.'
    end
  end
end
