FactoryBot.define do
  factory :oracle_tag do
    sequence(:slug) { |n| "tag-#{n}" }
    label { slug.tr('-', ' ') }
    scryfall_id { SecureRandom.uuid }
    source { 'scryfall' }

    trait :user_created do
      scryfall_id { nil }
      source { 'user' }
    end
  end
end
