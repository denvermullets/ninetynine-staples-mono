# A network game's finished GameRecord, kept compressed. The Host uploads it once, after the game is over.
# seat_holders lists who held each Seat, as [{ 'seat' => 0, 'user_id' => 12 }]; a Seat nobody held has a
# null user_id.
class GameRecord < ApplicationRecord
  MAX_COMPRESSED_BYTES = 2.megabytes
  END_STATUSES = %w[finished unfinished].freeze

  # records are deleted once they are this old
  RETENTION = 30.days

  belongs_to :room

  scope :held_by, ->(user) { where('seat_holders @> ?', [{ user_id: user.id }].to_json) }
  scope :expired, -> { where(created_at: ..RETENTION.ago) }

  validates :end_status, inclusion: { in: END_STATUSES }
  validates :room_id, uniqueness: true
  validate :seat_holders_are_room_members

  def self.purge_expired! = expired.in_batches.delete_all

  # the record text compressed for storage
  def self.compress(text)
    ActiveSupport::Gzip.compress(text)
  end

  def too_large? = data.bytesize > MAX_COMPRESSED_BYTES

  def record_text = ActiveSupport::Gzip.decompress(data)

  def holder?(user) = seat_holders.any? { |entry| entry['user_id'] == user.id }

  private

  def seat_holders_are_room_members
    seats = seat_holders.pluck('seat')
    errors.add(:seat_holders, 'must name at least one Seat') if seats.empty?
    errors.add(:seat_holders, 'repeat a Seat') if seats.uniq.size != seats.size
    return if room.nil?

    ids = seat_holders.pluck('user_id').compact
    errors.add(:seat_holders, 'include someone who is not in the Room') if (ids - room.member_ids).any?
  end
end
