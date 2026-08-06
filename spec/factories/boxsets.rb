FactoryBot.define do
  factory :boxset do
    sequence(:code) { |n| "SET#{n}" }
    # several views and Collections::BoxsetOptions call .downcase on this without a guard
    keyrune_code { 'pmtg1' }
    name { 'Example Set' }
    release_date { '2024-01-01' }
    base_set_size { 100 }
    total_set_size { 120 }
    set_type { 'core' }
  end
end
