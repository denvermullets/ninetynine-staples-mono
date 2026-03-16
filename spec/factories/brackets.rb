FactoryBot.define do
  factory :bracket do
    sequence(:level) { |n| n }
    name { "Bracket #{level}" }
    description { "Bracket level #{level}" }
    enabled { true }
  end
end
