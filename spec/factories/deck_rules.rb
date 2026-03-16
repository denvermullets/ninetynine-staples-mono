FactoryBot.define do
  factory :deck_rule do
    name { 'Max Game Changers' }
    rule_type { 'max_game_changers' }
    value { 0 }
    bracket
    enabled { true }
  end
end
