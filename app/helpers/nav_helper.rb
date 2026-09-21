# The main nav's menus, defined once so the desktop dropdowns and the mobile sections cannot drift
# apart. A menu is { key:, label:, badge:, items: } and an item is either { heading: } or
# { label:, path:, badge: } - a badge is the notifiable type handed to unread_badge.
module NavHelper
  def nav_menus
    return [browse_nav_menu] unless current_user

    [browse_nav_menu, collection_nav_menu, decks_nav_menu, trades_nav_menu]
  end

  # The menu the current page sits under. nav_item_classes matches on substrings, which cannot tell
  # /collections/<username> from /collections/<username>/trades, so the sections are told apart here -
  # most specific first.
  def nav_section
    path = request.path

    return :trades if trades_nav_path?(path)
    return :decks if decks_nav_path?(path)
    return :collection if collection_nav_path?(path)

    :browse if path == '/' || path.start_with?('/boxsets', '/precon-decks', '/commanders')
  end

  def nav_menu_classes(menu)
    nav_active_classes(nav_section == menu[:key])
  end

  def nav_menu_item_classes(item)
    nav_active_classes(request.path == item[:path])
  end

  private

  def nav_active_classes(active)
    "px-4 py-2 rounded-3xl text-nav-text #{active ? 'border-nav-text border' : 'border-transparent'}"
  end

  # anyone's trade or want list counts - browsing them is how a trade starts
  def trades_nav_path?(path)
    path.start_with?('/trades', '/wants', '/following') || path.match?(%r{\A/collections/[^/]+/(trades|wants)\z})
  end

  def decks_nav_path?(path)
    return false unless current_user

    username = current_user.username
    path.start_with?("/decks/#{username}", "/game-tracker/#{username}", '/deck-compare') ||
      path == "/collections/#{username}/brew"
  end

  def collection_nav_path?(path)
    return false unless current_user

    path.start_with?("/collections/#{current_user.username}", '/scan-cards', '/bulk-edit', '/import-collection')
  end

  def browse_nav_menu
    { key: :browse, label: 'Browse', items: [
      { label: 'Boxsets', path: boxsets_path },
      { label: 'Precons', path: precon_decks_path },
      { label: 'Commanders', path: commanders_path }
    ] }
  end

  def collection_nav_menu
    username = current_user.username

    { key: :collection, label: 'Collection', items: [
      { label: 'Overview', path: collections_overview_path(username) },
      { label: 'All Cards', path: collection_show_path(username) },
      { label: 'Stats', path: collections_stats_path(username) },
      { label: 'Sets', path: collection_sets_path(username) },
      { label: 'Reserved List', path: collection_reserved_path(username) },
      { label: 'Proxies', path: collection_proxies_path(username) },
      { heading: 'Manage' },
      { label: 'Scan Cards', path: card_scanner_path },
      { label: 'Bulk Edit', path: bulk_edit_path },
      { label: 'Import Collection', path: new_collection_import_path }
    ] }
  end

  def decks_nav_menu
    username = current_user.username

    { key: :decks, label: 'Decks', items: [
      { label: 'My Decks', path: decks_index_path(username) },
      { label: 'Brew', path: collection_brew_path(username) },
      { label: 'Compare Decks', path: deck_compare_path },
      { label: 'Game Tracker', path: game_tracker_path(username) }
    ] }
  end

  def trades_nav_menu
    username = current_user.username

    { key: :trades, label: 'Trades', badge: 'Trade', items: [
      { label: 'Inbox', path: trades_path, badge: 'Trade' },
      { label: 'Trade List', path: collection_trades_path(username) },
      { label: 'Want List', path: collection_wants_path(username) },
      { label: 'Want Matches', path: want_matches_path },
      { label: 'Following', path: following_path }
    ] }
  end
end
