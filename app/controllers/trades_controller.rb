# The trade builder, the inbox, and each trade's own page.
#
# Every action is session-scoped. The proposer is always current_user and the counterparty rides in
# `with` as a username, so there is no path a logged-out visitor or a wrong user can take to write a
# trade - the username-scoped half of trading is CollectionTradesController, which is read-only.
#
# The draft itself never touches the database. The page keeps it in Stimulus state and posts it to
# #preview for totals, then submits the same list to #create, which is the only point anything is
# written. Nothing is saved until then: there is no draft status and a half-built trade left on
# screen is just a page nobody submitted.
#
# A counter-offer is the same builder and the same #create, with `counter` naming the trade being
# answered. The builder starts pre-filled from it, and Trades::Propose decides whether it may be
# answered at all. The want matches page opens the same builder with `want_ids`, which pre-fills the
# other side from those wants (Trades::WantDraft) and changes nothing else.
#
# A trade is only ever found through current_user.trades, so anyone who is not one of its two parties
# gets a 404 - not a 403, which would confirm the trade exists.
class TradesController < ApplicationController
  PER_PAGE = 25
  WANTERS_SHOWN = 5
  TRANSITION_NOTICES = {
    'accept' => 'Trade accepted. Swap the cards, then confirm once yours arrive.',
    'decline' => 'Trade declined.',
    'cancel' => 'Trade cancelled.',
    'complete' => 'Marked as received.'
  }.freeze

  before_action :authenticate_user!
  before_action :set_recipient, only: :new
  before_action :set_parent, only: :new
  before_action :find_parent, only: :create
  before_action :set_trade, only: %i[show transition]

  def index
    inbox = Trades::Inbox.call(user: current_user, tab: params[:tab])
    @tab = inbox[:tab]
    @counts = inbox[:counts]
    @pagy, @trades = pagy(:offset, inbox[:trades], limit: PER_PAGE)
    # "who wants what I'm trading": the best few, and how many there are in all
    @wanters = WantList::Matches.call(user: current_user, direction: :inverse, per_page: WANTERS_SHOWN)
  end

  # opening the trade is reading about it, however the viewer got here
  def show
    current_user.notifications.about(@trade).mark_all_read!
    @detail = Trades::Detail.call(trade: @trade, viewer: current_user)
  end

  def transition
    result = Trades::Transition.call(trade: @trade, user: current_user, event: params[:event])
    return render_error_toast(result[:error]) unless result[:success]

    redirect_to trade_path(@trade), notice: TRANSITION_NOTICES[params[:event]], status: :see_other
  end

  def new
    @their_rows = Trades::AvailableRows.call(user: @recipient, except_trade: @parent)
    @my_rows = Trades::AvailableRows.call(user: current_user, except_trade: @parent)
    @prefill = starting_draft
    @totals = draft_totals(@recipient)
  end

  # totals for the draft as it stands, swapped into the page as a turbo-stream fragment
  def preview
    @recipient = User.find_by(username: params[:with])
    return head :unprocessable_entity if @recipient.nil?

    @totals = draft_totals(@recipient)
    # the draft is posted as JSON, so the format has to be named rather than negotiated
    render :preview, formats: :turbo_stream
  end

  def create
    result = Trades::Propose.call(proposer: current_user, recipient: User.find_by(username: params[:with]),
                                  items: submitted_items, message: params[:message].presence, parent: @parent)
    return render_error_toast(result[:error]) unless result[:success]

    noun = @parent ? 'Counter-offer sent' : 'Trade proposed'
    redirect_to trade_path(result[:trade]), notice: "#{noun} to #{result[:trade].recipient.username}."
  end

  private

  def set_trade
    @trade = current_user.trades
                         .includes(:proposer, :recipient, :parent_trade, :counter_offers,
                                   trade_events: :user, trade_items: { magic_card: :boxset })
                         .find_by(id: params[:id])
    head :not_found if @trade.nil?
  end

  def set_recipient
    @recipient = User.find_by(username: params[:with])
    return redirect_to root_path, alert: 'We could not find that user.' if @recipient.nil?
    return redirect_to root_path, alert: 'You cannot trade with yourself.' if @recipient.id == current_user.id
    return if @recipient.trades_public?

    redirect_to root_path, alert: "#{@recipient.username} is not accepting trade offers."
  end

  # only the offer's recipient, answering the user who made it, gets a pre-filled counter builder -
  # Trades::Propose would refuse anything else on submit, so there is no point drafting it
  def set_parent
    return if params[:counter].blank?

    @parent = current_user.trades.includes(:trade_items).find_by(id: params[:counter])
    return if @parent&.counterable_by?(current_user) && @parent.proposer_id == @recipient.id

    redirect_to trades_path, alert: 'That trade can no longer be countered.'
  end

  # whether it may still be countered is Trades::Propose's call; this only makes sure it is theirs
  def find_parent
    return if params[:counter].blank?

    @parent = current_user.trades.find_by(id: params[:counter])
    render_error_toast('We could not find that trade.') if @parent.nil?
  end

  # a counter-offer starts from the trade it answers, "Propose trade" on the want matches page from the
  # wants it named, and "Add to trade" from one printing
  def starting_draft
    return Trades::CounterDraft.call(parent: @parent, rows: @their_rows + @my_rows) if @parent
    return preselected if params[:want_ids].blank?

    Trades::WantDraft.call(proposer: current_user, want_ids: want_ids, rows: @their_rows)
  end

  # comma-separated, as the matches page writes it; anything that is not a positive id is ignored
  def want_ids
    params[:want_ids].to_s.split(',').map(&:to_i).select(&:positive?)
  end

  # "Add to trade" on a trade list names a printing, but a proposal is written in collection rows -
  # so the first row offering that printing is the one that starts with a copy in it.
  def preselected
    card_id = params[:card].to_i
    return {} unless card_id.positive?

    row = @their_rows.find { |candidate| candidate.magic_card.id == card_id }
    return {} if row.nil?

    { row.id => row.quantity.positive? ? { quantity: 1, foil_quantity: 0 } : { quantity: 0, foil_quantity: 1 } }
  end

  def draft_totals(recipient)
    Trades::DraftTotals.call(proposer: current_user, recipient: recipient, items: submitted_items)
  end

  # #preview posts the draft as a JSON array; the form posts it as index-keyed hidden fields, which
  # arrive as a hash. Both are the same list of items either way round.
  def submitted_items
    items = params[:items]
    rows = items.respond_to?(:values) ? items.values : Array(items)

    rows.map { |row| row.permit(:collection_magic_card_id, :side, :quantity, :foil_quantity).to_h }
  end

  def render_error_toast(message)
    flash.now[:type] = 'error'
    render turbo_stream: turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: message }),
           status: :unprocessable_entity
  end
end
