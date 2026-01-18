class CommanderGame < ApplicationRecord
  belongs_to :user
  belongs_to :tracked_deck

  has_many :game_opponents, dependent: :destroy

  accepts_nested_attributes_for :game_opponents, allow_destroy: true, reject_if: :all_blank

  WIN_CONDITIONS = [
    'Combat',
    'Commander Damage',
    'Combo',
    'Mill',
    'Infect',
    'Alternate Win',
    'Concession',
    'Other'
  ].freeze

  validates :played_on, presence: true
  validates :won, inclusion: { in: [true, false] }
  validates :pod_size, numericality: { in: 2..8 }, allow_nil: true
  validates :bracket_level, numericality: { in: 1..5 }, allow_nil: true
  validates :fun_rating, numericality: { in: 1..10 }, allow_nil: true
  validates :performance_rating, numericality: { in: 1..10 }, allow_nil: true
  validates :turn_ended_on, numericality: { greater_than: 0 }, allow_nil: true
  validates :win_condition, inclusion: { in: WIN_CONDITIONS }, allow_blank: true

  scope :wins, -> { where(won: true) }
  scope :losses, -> { where(won: false) }
  scope :by_bracket, ->(level) { where(bracket_level: level) }
  scope :recent, -> { order(played_on: :desc, created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }

  def result_text
    won? ? 'Win' : 'Loss'
  end

  def result_badge_class
    won? ? 'bg-accent-50/20 text-accent-50' : 'bg-accent-100/20 text-accent-100'
  end

  def opponent_count
    game_opponents.count
  end

  def winning_opponent
    game_opponents.find_by(won: true)
  end

  def deck_name
    tracked_deck.name
  end

  def commander_name
    tracked_deck.commander_display_name
  end
end
