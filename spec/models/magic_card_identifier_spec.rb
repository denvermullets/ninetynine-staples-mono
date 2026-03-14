require 'rails_helper'

RSpec.describe MagicCardIdentifier, type: :model do
  let(:magic_card) { create(:magic_card) }

  it 'belongs to a magic card' do
    identifier = described_class.create!(magic_card: magic_card, scryfall_id: SecureRandom.uuid)
    expect(identifier.magic_card).to eq(magic_card)
  end

  it 'enforces unique magic_card_id' do
    described_class.create!(magic_card: magic_card, scryfall_id: SecureRandom.uuid)
    duplicate = described_class.new(magic_card: magic_card, scryfall_id: SecureRandom.uuid)
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'is accessible via magic_card association' do
    identifier = described_class.create!(magic_card: magic_card, scryfall_id: 'abc-123')
    expect(magic_card.magic_card_identifier).to eq(identifier)
  end
end
