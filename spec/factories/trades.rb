FactoryBot.define do
  factory :trade do
    association :proposer, factory: :user
    association :recipient, factory: :user
    status { 'proposed' }

    trait :accepted do
      status { 'accepted' }
    end

    # accepted with the proposer's half of the completion already confirmed
    trait :half_confirmed do
      status { 'accepted' }
      proposer_completed_at { Time.current }
    end
  end
end
