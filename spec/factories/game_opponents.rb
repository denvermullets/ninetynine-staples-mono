FactoryBot.define do
  factory :game_opponent do
    commander_game
    commander factory: :magic_card
    won { false }
  end
end
