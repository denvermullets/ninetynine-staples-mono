FactoryBot.define do
  factory :card_oracle_tag do
    oracle_tag
    scryfall_oracle_id { SecureRandom.uuid }
    weight { 'median' }
    source { 'scryfall' }

    trait :by_user do
      source { 'user' }
      user
    end
  end
end
