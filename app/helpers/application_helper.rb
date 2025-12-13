module ApplicationHelper
  MANA_SYMBOLS = {
    'W' => 'ms-w', 'U' => 'ms-u', 'B' => 'ms-b', 'R' => 'ms-r', 'G' => 'ms-g', 'C' => 'ms-c', 'X' => 'ms-x',
    'W/P' => 'ms-wp', 'U/P' => 'ms-up', 'B/P' => 'ms-bp', 'R/P' => 'ms-rp', 'G/P' => 'ms-gp', 'S' => 'ms-s',
    'E' => 'ms-e', 'W/U' => 'ms-wu', 'W/B' => 'ms-wb', 'U/B' => 'ms-ub', 'U/R' => 'ms-ur', 'B/R' => 'ms-br',
    'B/G' => 'ms-bg', 'R/W' => 'ms-rw', 'R/G' => 'ms-rg', 'G/W' => 'ms-gw', 'G/U' => 'ms-gu', '2/W' => 'ms-2w',
    '2/U' => 'ms-2u', '2/B' => 'ms-2b', '2/R' => 'ms-2r', '2/G' => 'ms-2g', 'W/U/P' => 'ms-wup', 'W/B/P' => 'ms-wbp',
    'U/B/P' => 'ms-ubp', 'U/R/P' => 'ms-urp', 'B/R/P' => 'ms-brp', 'B/G/P' => 'ms-bgp', 'R/W/P' => 'ms-rwp',
    'R/G/P' => 'ms-rgp', 'G/W/P' => 'ms-gwp', 'G/U/P' => 'ms-gup',
    '0' => 'ms-0', '1' => 'ms-1', '2' => 'ms-2', '3' => 'ms-3', '4' => 'ms-4',
    '5' => 'ms-5', '6' => 'ms-6', '7' => 'ms-7', '8' => 'ms-8', '9' => 'ms-9',
    '10' => 'ms-10', '11' => 'ms-11', '12' => 'ms-12', '13' => 'ms-13', '14' => 'ms-14',
    '15' => 'ms-15', '16' => 'ms-16', '17' => 'ms-17', '18' => 'ms-18', '19' => 'ms-19'
  }.freeze

  def mana_symbols(mana_cost)
    return if mana_cost.nil?

    # scan extracts all the contents between {} as individual symbols
    mana_cost.scan(/\{(.*?)\}/).map do |symbol|
      # scan returns an array of arrays
      symbol = symbol.first
      # in case i'm missing a code we will try to display it
      css_class = MANA_SYMBOLS[symbol] || "ms ms-#{symbol.downcase}"
      "<i class='no-tailwind ms ms-cost ml-0 #{css_class}'></i>"
    end.join.html_safe
  end

  def nav_item_classes(route)
    base_classes = 'px-4 py-2 rounded-3xl text-grey-text'
    active_classes = 'border-grey-text border'

    # add the active classes if the current request path matches the provided route
    if (request.path == '/' && route == '/boxsets') || request.path.include?(route)
      "#{base_classes} #{active_classes}"
    else
      "#{base_classes} border-transparent"
    end
  end

  def price_trend_class(trend)
    case trend
    when 'up'
      'text-green-500'
    when 'down'
      'text-red-500'
    else
      '' # default color from parent
    end
  end

  def current_user_admin?
    current_user&.role.to_i == 9001
  end
end
