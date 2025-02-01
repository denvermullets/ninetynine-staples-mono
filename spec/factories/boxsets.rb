FactoryBot.define do
  factory :boxset do
    code { 'SET123' }
    name { 'Example Set' }
    release_date { '2024-01-01' }
    base_set_size { 100 }
    total_set_size { 120 }
    set_type { 'core' }
  end
end
