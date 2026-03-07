require 'rails_helper'

RSpec.describe CardIngestion::CardCreator, type: :service do
  let(:boxset) { create(:boxset) }
  let(:card_uuid) { SecureRandom.uuid }
  let(:scryfall_id) { SecureRandom.uuid }
  let(:oracle_id) { SecureRandom.uuid }

  let(:card_data) do
    {
      'name' => 'Test Card',
      'text' => 'Test text',
      'type' => 'Creature',
      'uuid' => card_uuid,
      'number' => '1',
      'identifiers' => { 'scryfallId' => scryfall_id, 'scryfallOracleId' => oracle_id },
      'rarity' => 'common',
      'manaValue' => 2,
      'manaCost' => '{1}{R}',
      'leadershipSkills' => { 'commander' => false, 'brawl' => false, 'oathbreaker' => false }
    }
  end

  let(:empty_images) { { small: nil, normal: nil, large: nil, art_crop: nil } }

  before do
    allow(Scryfall::ImageFetcher).to receive(:call).and_return(empty_images)
  end

  context 'creating a new card' do
    it 'creates a MagicCard record' do
      expect { described_class.call(boxset: boxset, card_data: card_data) }
        .to change { MagicCard.count }.by(1)
    end

    it 'sets correct attributes' do
      card = described_class.call(boxset: boxset, card_data: card_data)
      expect(card.name).to eq('Test Card')
      expect(card.card_uuid).to eq(card_uuid)
      expect(card.boxset).to eq(boxset)
    end

    it 'sets prices to zero for new cards' do
      card = described_class.call(boxset: boxset, card_data: card_data)
      expect(card.normal_price).to eq(0)
      expect(card.foil_price).to eq(0)
    end
  end

  context 'updating an existing card' do
    let!(:existing_card) do
      create(:magic_card,
             card_uuid: card_uuid,
             name: 'Old Name',
             boxset: boxset,
             image_large: 'https://example.com/img.jpg',
             image_medium: 'https://example.com/img.jpg',
             image_small: 'https://example.com/img.jpg',
             art_crop: 'https://example.com/art.jpg',
             image_updated_at: 1.day.ago)
    end

    it 'does not create a new record' do
      expect { described_class.call(boxset: boxset, card_data: card_data) }
        .not_to(change { MagicCard.count })
    end

    it 'updates the existing card' do
      described_class.call(boxset: boxset, card_data: card_data)
      existing_card.reload
      expect(existing_card.name).to eq('Test Card')
    end
  end

  context 'for a token' do
    it 'creates a token card' do
      card = described_class.call(boxset: boxset, card_data: card_data, is_token: true)
      expect(card.is_token).to be true
    end
  end
end
