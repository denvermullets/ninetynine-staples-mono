# Wording for the trade builder's running total, the inbox, and the trade page.
module TradesHelper
  STATUS_CLASSES = {
    'proposed' => 'bg-background text-grey-text',
    'accepted' => 'bg-highlight text-nine-white',
    'completed' => 'bg-accent-50/20 text-accent-50',
    'declined' => 'bg-accent-100/20 text-accent-100',
    'countered' => 'bg-accent-200/20 text-accent-200',
    'cancelled' => 'bg-accent-100/20 text-accent-100'
  }.freeze

  ACTION_LABELS = {
    'accept' => 'Accept',
    'decline' => 'Decline',
    'cancel' => 'Cancel trade',
    'complete' => "I've received my cards"
  }.freeze

  # only the steps that close a trade for good ask first
  ACTION_CONFIRMS = {
    'decline' => 'Decline this trade? It cannot be reopened.',
    'cancel' => 'Cancel this trade? It cannot be reopened.'
  }.freeze

  EVENT_VERBS = {
    'proposed' => 'proposed the trade',
    'accepted' => 'accepted',
    'declined' => 'declined',
    'countered' => 'declined with a counter-offer',
    'cancelled' => 'cancelled',
    'confirmed' => 'confirmed receipt'
  }.freeze

  # The difference is what the viewer receives minus what they give - the builder is only ever looked
  # at by the proposer, and Trades::Detail turns the trade page to face whoever is reading it - so a
  # positive number is value coming their way.
  def trade_difference_tone(difference)
    return :positive if difference.positive?
    return :negative if difference.negative?

    :neutral
  end

  def trade_difference_text(difference)
    return 'an even trade' if difference.zero?

    difference.positive? ? 'in your favour' : 'in their favour'
  end

  def trade_side_sub(side)
    "#{pluralize(side[:copies], 'copy')} · #{number_to_currency(side[:buylist])} buylist"
  end

  # nav_item_classes matches on substrings, and a user's own trade list lives at
  # /collections/<username>/trades - so the inbox link only lights up on paths that start with it
  def trades_nav_classes
    nav_item_classes(*(request.path.start_with?('/trades') ? ['/trades'] : []))
  end

  # a countered trade is declined as far as the state machine goes, but it reads as a conversation
  # still going rather than a no
  def trade_status_badge(trade)
    status = trade.countered? ? 'countered' : trade.status
    tag.span status.capitalize,
             class: "px-2 py-0.5 text-xs rounded-full whitespace-nowrap #{STATUS_CLASSES.fetch(status)}"
  end

  # an inbox row's side, at the prices the trade was proposed at
  def trade_side_summary(trade, side)
    items = trade.items_for(side)

    "#{pluralize(items.sum(&:total_copies), 'copy')} · #{number_to_currency(items.sum(0.to_d, &:retail_value))}"
  end

  # an accepted trade the viewer still has to confirm is the one thing in the inbox waiting on them
  def trade_waiting_on_you?(trade, user)
    (trade.proposed? && trade.recipient_id == user.id) || (trade.accepted? && !trade.confirmed_by?(user))
  end

  # The other party's name wherever a trade page says it, linked to their collections. `suffix` rides
  # along outside the link ("henry gives"), so headings can be built without concatenating markup.
  def trade_user_link(user, suffix = nil)
    link = link_to(user.username, collection_show_path(user.username),
                   class: 'underline decoration-highlight underline-offset-4 hover:text-accent-50')

    safe_join([link, suffix].compact, ' ')
  end

  def trade_party_name(user, viewer)
    user == viewer ? 'You' : user.username
  end

  # `entry` is one step of Trades::Thread. A counter-offer's own `proposed` step is the counter.
  def trade_event_text(entry, viewer)
    event = entry[:event]
    return 'Trade completed' if event.event == 'completed'

    actor = event.user ? trade_party_name(event.user, viewer) : 'A former user'
    return "#{actor} countered with a new offer" if event.event == 'proposed' && entry[:trade].parent_trade_id

    "#{actor} #{EVENT_VERBS.fetch(event.event)}"
  end

  # What the trade is waiting on, one sentence per line, for the panel above the action buttons. On
  # an accepted trade that is each side's receipt confirmation.
  def trade_progress_lines(trade, detail)
    them = detail[:theirs][:user].username
    return [my_confirmation_line(detail[:mine]), their_confirmation_line(detail[:theirs], them)] if trade.accepted?
    return ["Waiting on #{them} to answer."] if trade.proposer_id == detail[:mine][:user].id

    ["#{them} is waiting on your answer. Accept it, decline it, or counter with changes of your own."]
  end

  def trade_time(time)
    time.strftime('%b %-d, %Y · %-l:%M %p')
  end

  def my_confirmation_line(side)
    return 'Once your cards arrive, confirm it here.' if side[:confirmed_at].nil?

    "You confirmed your cards arrived on #{trade_time(side[:confirmed_at])}."
  end

  def their_confirmation_line(side, them)
    return "Waiting on #{them} to confirm theirs arrived." if side[:confirmed_at].nil?

    "#{them} confirmed their cards arrived on #{trade_time(side[:confirmed_at])}."
  end

  # "2 × $5.00" and "1 foil × $10.00", one per finish actually on offer
  def trade_item_breakdown(item)
    regular, foil = item.unit_prices
    lines = []
    lines << "#{item.quantity} × #{number_to_currency(regular)}" if item.quantity.positive?
    lines << "#{item.foil_quantity} foil × #{number_to_currency(foil)}" if item.foil_quantity.positive?
    lines.join(' · ')
  end
end
