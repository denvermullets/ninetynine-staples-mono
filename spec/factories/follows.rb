FactoryBot.define do
  factory :follow do
    follower factory: :user
    followed factory: :user
  end
end
