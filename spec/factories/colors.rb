FactoryBot.define do
  factory :color do
    # The five rows are a fixed set, not sample data - Commanders::ColorMask keys its bits on these
    # exact names. Callers pass the one they want.
    name { 'W' }
  end
end
