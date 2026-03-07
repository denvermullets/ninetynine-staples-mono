require 'rails_helper'

RSpec.describe CardIngestion::AttributeCreator, type: :service do
  let(:magic_card) { create(:magic_card) }

  let(:card_data) do
    {
      'artist' => 'Test Artist',
      'subtypes' => %w[Human Wizard],
      'supertypes' => ['Legendary'],
      'types' => %w[Creature],
      'colors' => %w[U],
      'colorIdentity' => %w[U R],
      'keywords' => %w[Flying Haste],
      'legalities' => { 'commander' => 'Legal', 'standard' => 'Banned' },
      'finishes' => %w[nonfoil foil],
      'frameEffects' => %w[legendary],
      'rulings' => [{ 'text' => 'This is a ruling.', 'date' => '2024-01-01' }]
    }
  end

  subject { described_class.call(magic_card: magic_card, card_data: card_data) }

  it 'returns the magic card' do
    expect(subject).to eq(magic_card)
  end

  it 'creates the artist' do
    expect { subject }.to change { Artist.count }.by(1)
  end

  it 'creates subtypes' do
    expect { subject }.to change { magic_card.sub_types.count }.by(2)
  end

  it 'creates supertypes' do
    expect { subject }.to change { magic_card.super_types.count }.by(1)
  end

  it 'creates card types' do
    expect { subject }.to change { magic_card.card_types.count }.by(1)
  end

  it 'creates colors' do
    expect { subject }.to change { MagicCardColor.where(magic_card: magic_card).count }.by(1)
  end

  it 'creates keywords' do
    expect { subject }.to change { magic_card.keywords.count }.by(2)
  end

  it 'creates legalities' do
    expect { subject }.to change { MagicCardLegality.count }.by(2)
  end

  it 'creates finishes' do
    expect { subject }.to change { magic_card.finishes.count }.by(2)
  end

  context 'with nil arrays' do
    let(:card_data) { {} }

    it 'handles missing data gracefully' do
      expect { subject }.not_to raise_error
    end
  end

  context 'when called twice (idempotent)' do
    it 'does not duplicate records' do
      described_class.call(magic_card: magic_card, card_data: card_data)
      expect {
        described_class.call(magic_card: magic_card, card_data: card_data)
      }.not_to(change { Artist.count })
    end
  end
end
