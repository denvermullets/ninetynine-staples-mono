FactoryBot.define do
  factory :price_alert do
    user
    kind { 'threshold' }
    magic_card
    finish { 'normal' }
    direction { 'above' }
    threshold_price { 20 }

    trait :movement_rule do
      kind { 'movement' }
      magic_card { nil }
      finish { 'any' }
      direction { 'both' }
      threshold_price { nil }
      window { 'daily' }
      min_delta_amount { 5 }
    end

    trait :card_override do
      movement_rule
      magic_card
    end
  end
end
