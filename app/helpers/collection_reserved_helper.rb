# Sort links for the Reserved List page, shared by the sort pills and the table headings so the two
# cannot disagree about which way a click goes.
module CollectionReservedHelper
  # Clicking the sort already in force flips it; clicking any other sort drops the direction so the
  # service opens it its own default way - price dearest first, names A to Z.
  def sort_params(key, sort, direction)
    return { sort: key, direction: nil } unless key == sort

    { sort: key, direction: direction == 'asc' ? 'desc' : 'asc' }
  end
end
