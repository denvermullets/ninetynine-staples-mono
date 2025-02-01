FactoryBot.define do
  factory :magic_card do
    name { 'Black Lotus' }
    normal_price { 5.0 }
    foil_price { 10.0 }
    association :boxset
  end
end
