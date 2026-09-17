FactoryBot.define do
  factory :trade_item do
    trade
    magic_card
    side { 'proposer' }
    quantity { 1 }
    foil_quantity { 0 }
    unit_price_snapshot { 5.0 }
    unit_foil_price_snapshot { 10.0 }
    unit_buylist_snapshot { 2.0 }
    unit_buylist_foil_snapshot { 4.0 }
  end
end
