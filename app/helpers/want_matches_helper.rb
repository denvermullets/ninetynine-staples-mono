module WantMatchesHelper
  # the copies a match is about: what is marked for trade when anything is, otherwise what they own.
  # Both are already cut down to the finish the want accepts.
  def want_match_counts(match)
    match.tradeable ? [match.trade_quantity, match.trade_foil_quantity] : [match.quantity, match.foil_quantity]
  end

  # the unit price of each finish in want_match_counts, with Trades::UnitPrice's fallbacks so a
  # foil with no foil price is not shown as free
  def want_match_prices(match)
    regular_count, foil_count = want_match_counts(match)
    regular_price, foil_price = Trades::UnitPrice.pair(match.printing.normal_price, match.printing.foil_price)

    parts = []
    parts << number_to_currency(regular_price) if regular_count.positive?
    parts << "#{number_to_currency(foil_price)} foil" if foil_count.positive?
    parts.join(' / ')
  end
end
