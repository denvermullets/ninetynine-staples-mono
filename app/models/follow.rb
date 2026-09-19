# One user following another. One-way, like a Discogs friend: nothing is asked of the person being
# followed, and following gives no access a stranger would not have - a private trade list stays
# private. It only decides whose offers the follower is shown first, or at all where listing every
# user would not scale (MagicCards::TradeHolders).
class Follow < ApplicationRecord
  belongs_to :follower, class_name: 'User', inverse_of: :active_follows
  belongs_to :followed, class_name: 'User', inverse_of: :passive_follows

  validates :followed_id, uniqueness: { scope: :follower_id }
  validate :not_self

  private

  def not_self
    errors.add(:followed, 'cannot be yourself') if follower_id.present? && follower_id == followed_id
  end
end
