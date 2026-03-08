FactoryBot.define do
  factory :commander_game do
    played_on { Date.current }
    won { false }
    pod_size { 4 }
    user
    tracked_deck
  end
end
