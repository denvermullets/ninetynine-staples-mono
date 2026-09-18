# The "you own this now, take it off your want list?" toast for actions that add copies through
# CollectionRecord::CreateOrUpdate. Only ever about current_user's own wants: the service reports
# the collection owner's rows, and nobody else should see those.
module WantsFilledToast
  extend ActiveSupport::Concern

  private

  # an array so callers can splat it into their turbo_stream list; empty when nothing was filled.
  # remove_params are posted back with each remove button so the refreshed card_details frame matches
  def wants_filled_toast(result, remove_params = {})
    items = Array(result[:wants_filled]).select { |item| item.user_id == current_user&.id }
    return [] if items.empty?

    [turbo_stream.append('toasts', partial: 'shared/wants_filled_toast',
                                   locals: { items:, username: current_user.username, remove_params: })]
  end
end
