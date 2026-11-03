# Who the trade builder is drafting with, and which trade it answers, for every action that draws part
# of it. Each one redirects rather than drafting something Trades::Propose would refuse on submit.
module TradeBuilderParties
  extend ActiveSupport::Concern

  private

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
end
