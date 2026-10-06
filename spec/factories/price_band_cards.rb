FactoryBot.define do
  factory :price_band_card do
    band factory: %i[price_alert band]
    magic_card
    finish { 'normal' }
    state { 'armed' }

    # on the worklist: crossed and not yet handled
    trait :to_do do
      state { 'crossed' }
      crossed_on { Date.current }
      crossed_price { 1.05 }
      moved { 'up' }
    end

    trait :done do
      to_do
      handled_at { 1.hour.ago }
    end
  end
end
