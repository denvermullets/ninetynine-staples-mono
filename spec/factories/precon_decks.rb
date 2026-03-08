FactoryBot.define do
  factory :precon_deck do
    sequence(:code) { |n| "PDK#{n}" }
    sequence(:file_name) { |n| "precon_deck_#{n}" }
    sequence(:name) { |n| "Precon Deck #{n}" }
    release_date { 1.week.ago.to_date }
  end
end
