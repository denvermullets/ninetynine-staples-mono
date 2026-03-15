FactoryBot.define do
  factory :game_changer do
    sequence(:oracle_id) { |_n| SecureRandom.uuid }
    sequence(:card_name) { |n| "Game Changer Card #{n}" }
    reason { 'Too powerful' }
  end
end
