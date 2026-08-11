FactoryBot.define do
  factory :card_role do
    scryfall_oracle_id { SecureRandom.uuid }
    role { 'removal' }
    effect { 'targeted_removal' }
    confidence { 1.0 }
  end
end
