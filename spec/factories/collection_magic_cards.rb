FactoryBot.define do
  factory :collection_magic_card do
    collection
    magic_card
    quantity { 1 }
    foil_quantity { 0 }
    buy_price { 4.0 }
    sell_price { 6.0 }

    # every owned copy on the row is up for trade
    trait :tradeable do
      trade_quantity { quantity }
      trade_foil_quantity { foil_quantity }
    end
  end
end
