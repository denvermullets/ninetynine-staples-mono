FactoryBot.define do
  factory :want_list_item do
    user
    magic_card
    any_printing { true }
    quantity { 1 }
    foil_preference { 'any' }

    trait :specific_printing do
      any_printing { false }
    end

    trait :foil do
      foil_preference { 'foil' }
    end
  end
end
