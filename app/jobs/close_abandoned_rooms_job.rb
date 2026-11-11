# Closes network game Rooms whose Host has been gone for 24 hours, so their Join codes die and members
# stop holding subscriptions to a game nobody is running.
class CloseAbandonedRoomsJob < ApplicationJob
  queue_as :background

  def perform
    Room.close_abandoned!
  end
end
