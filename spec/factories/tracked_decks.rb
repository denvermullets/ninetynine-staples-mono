FactoryBot.define do
  factory :tracked_deck do
    sequence(:name) { |n| "Deck #{n}" }
    status { 'active' }
    user
    commander factory: :magic_card
  end
end
