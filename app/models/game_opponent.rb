class GameOpponent < ApplicationRecord
  belongs_to :commander_game
  belongs_to :commander, class_name: 'MagicCard'
  belongs_to :partner_commander, class_name: 'MagicCard', optional: true

  validates :win_condition, inclusion: { in: CommanderGame::WIN_CONDITIONS }, allow_blank: true

  scope :winners, -> { where(won: true) }
  scope :losers, -> { where(won: false) }

  def commander_display_name
    if partner_commander.present?
      "#{commander.name} / #{partner_commander.name}"
    else
      commander.name
    end
  end
end
