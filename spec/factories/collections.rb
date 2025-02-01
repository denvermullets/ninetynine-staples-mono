FactoryBot.define do
  factory :collection do
    name { 'Grey Box 1' }
    description { 'All my Rare cards' }
    collection_type { 'binder' }
    total_value { 0 }
    total_quantity { 0 }
    total_foil_quantity { 0 }
    # links this to a user
    user
  end
end
