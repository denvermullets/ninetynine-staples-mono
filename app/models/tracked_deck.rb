class TrackedDeck < ApplicationRecord
  belongs_to :user
  belongs_to :commander, class_name: 'MagicCard'
  belongs_to :partner_commander, class_name: 'MagicCard', optional: true

  has_many :commander_games, dependent: :destroy

  STATUSES = %w[active worth_upgrading chopping_block retired].freeze

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: 'active') }
  scope :retired, -> { where(status: 'retired') }
  scope :not_retired, -> { where.not(status: 'retired') }
  scope :chopping_block, -> { where(status: 'chopping_block') }
  scope :by_user, ->(user_id) { where(user_id: user_id) }

  def games_count
    commander_games.count
  end

  def wins_count
    commander_games.where(won: true).count
  end

  def losses_count
    commander_games.where(won: false).count
  end

  def win_rate
    return 0.0 if games_count.zero?

    (wins_count.to_f / games_count * 100).round(1)
  end

  def avg_fun_rating
    commander_games.where.not(fun_rating: nil).average(:fun_rating)&.round(1)
  end

  def avg_performance_rating
    commander_games.where.not(performance_rating: nil).average(:performance_rating)&.round(1)
  end

  def last_played_on
    commander_games.maximum(:played_on)
  end

  def commander_display_name
    if partner_commander.present?
      "#{commander.name} / #{partner_commander.name}"
    else
      commander.name
    end
  end

  def dropdown_display_name
    "#{commander_display_name} - #{name}"
  end

  STATUS_BADGE_CLASSES = {
    'active' => 'bg-accent-50/20 text-accent-50',
    'worth_upgrading' => 'bg-accent-300/20 text-accent-300',
    'chopping_block' => 'bg-accent-100/20 text-accent-100',
    'retired' => 'bg-gray-500/20 text-gray-400'
  }.freeze

  def status_badge_class
    STATUS_BADGE_CLASSES[status]
  end
end
