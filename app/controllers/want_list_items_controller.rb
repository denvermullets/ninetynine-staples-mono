# The "Want" block inside the expanded card details. Every action answers with a turbo stream that
# swaps the open card_details frame, so the forms post back the params the frame was loaded with.
#
# The want list page edits and removes through the same actions with return_to=want_list. Those are
# answered with a redirect back to the page instead: its pill counts and "now owned" column all move
# with an edit, so the list is reloaded rather than patched row by row.
class WantListItemsController < ApplicationController
  include CardDetailsLocals

  before_action :authenticate_user!

  def create
    card = MagicCard.find_by(id: params[:magic_card_id])
    return render_error_toast('Card not found.') unless card

    result = WantList::Upsert.call(user: current_user, magic_card: card, attributes: want_params)
    return render_error_toast(result[:error]) unless result[:success]

    render_want_success(card.id, "#{result[:created] ? 'Added' : 'Updated'} #{result[:name]} on your want list.")
  end

  def update
    item = find_item
    return render_error_toast('Card not found on your want list.') unless item

    result = WantList::Upsert.call(user: current_user, item:, attributes: want_params)
    return render_error_toast(result[:error]) unless result[:success]

    render_want_success(item.magic_card_id, "Updated #{result[:name]} on your want list.")
  end

  def destroy
    item = find_item
    return render_error_toast('Card not found on your want list.') unless item

    result = WantList::Remove.call(item:)

    render_want_success(item.magic_card_id, "Removed #{result[:name]} from your want list.")
  end

  private

  # scoped through current_user so a user can only touch their own wants
  def find_item
    current_user.want_list_items.find_by(id: params[:id])
  end

  # An any-printing want shows up on every printing of the card, and the other-printings table edits
  # printings whose row isn't open, so refresh the row the user is looking at instead.
  def render_want_success(mutated_card_id, message)
    return redirect_to_want_list(notice: message) if from_want_list?

    flash.now[:type] = 'success'
    card = MagicCard.find(params[:refresh_card_id].presence || mutated_card_id)

    render turbo_stream: [
      turbo_stream.replace("card_details_#{card.id}", partial: 'magic_cards/details',
                                                      locals: card_details_locals(card)),
      # the mobile card expands in place rather than through the lazy frame; absent targets are ignored
      turbo_stream.replace("mobile_want_control_#{card.id}", partial: 'shared/cards/want_control',
                                                             locals: { magic_card: card, mobile: true }),
      turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: })
    ]
  end

  def render_error_toast(message)
    return redirect_to_want_list(alert: message) if from_want_list?

    flash.now[:type] = 'error'
    render turbo_stream: turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: })
  end

  def from_want_list?
    params[:return_to] == 'want_list'
  end

  # back to the view the owner was on; the page whitelists filter and sort itself
  def redirect_to_want_list(flash_options)
    view = params.permit(:filter, :sort, :page).to_h.compact_blank

    redirect_to collection_wants_path(current_user.username, **view.symbolize_keys),
                status: :see_other, **flash_options
  end

  def want_params
    params.permit(:quantity, :foil_preference, :any_printing, :notes)
  end
end
