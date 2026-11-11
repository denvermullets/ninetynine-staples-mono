# A network game's Room. The Host creates it and shares its Join code; signed-in users join with the code
# until the Host marks the Room started or closes it. Membership (the Host included) is what lets a user
# subscribe to the Relay for this Room.
class Room < ApplicationRecord
  # the Host plus three Participants
  MAX_MEMBERS = 4
  # no 0/O, 1/I/L or 5/S, so a code read aloud or off a screenshot can't be mistyped
  CODE_ALPHABET = %w[2 3 4 6 7 8 9 A B C D E F G H J K M N P Q R T V W X Y Z].freeze
  CODE_LENGTH = 6
  STATUSES = %w[open started closed].freeze

  belongs_to :host, class_name: 'User'
  has_many :room_memberships, dependent: :destroy
  has_many :members, through: :room_memberships, source: :user
  has_one :game_record, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :join_code, presence: true

  scope :live, -> { where.not(status: 'closed') }

  # a Room with the Host as its first member and a code no live Room is using
  def self.open_for!(host)
    attempts = 0
    begin
      transaction do
        room = create!(host: host, join_code: generate_code)
        room.room_memberships.create!(user: host)
        room
      end
    rescue ActiveRecord::RecordNotUnique
      attempts += 1
      retry if attempts < 5
      raise
    end
  end

  def self.generate_code
    loop do
      code = Array.new(CODE_LENGTH) { CODE_ALPHABET.sample(random: SecureRandom) }.join
      return code unless live.exists?(join_code: code)
    end
  end

  # the live Room with this code, however it was typed
  def self.find_live_by_code(code)
    live.find_by(join_code: code.to_s.strip.upcase)
  end

  def open? = status == 'open'
  def started? = status == 'started'
  def closed? = status == 'closed'
  def host?(user) = host_id == user.id
  def member?(user) = room_memberships.exists?(user_id: user.id)
  def full? = room_memberships.count >= MAX_MEMBERS

  def start!
    update!(status: 'started', started_at: Time.current)
  end

  def close!
    update!(status: 'closed', closed_at: Time.current)
  end
end
