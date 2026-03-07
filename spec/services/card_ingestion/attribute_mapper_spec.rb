require 'rails_helper'

RSpec.describe CardIngestion::AttributeMapper, type: :service do
  let(:boxset) { create(:boxset) }

  let(:card_data) do
    {
      'name' => 'Lightning Bolt',
      'text' => 'Deal 3 damage to any target.',
      'power' => nil,
      'toughness' => nil,
      'type' => 'Instant',
      'borderColor' => 'black',
      'frameVersion' => '2015',
      'isReprint' => false,
      'number' => '141',
      'identifiers' => { 'scryfallOracleId' => SecureRandom.uuid },
      'uuid' => SecureRandom.uuid,
      'rarity' => 'common',
      'manaCost' => '{R}',
      'manaValue' => 1,
      'edhrecRank' => 5,
      'leadershipSkills' => { 'commander' => false, 'brawl' => false, 'oathbreaker' => false }
    }
  end

  context 'for a regular card' do
    it 'maps base attributes' do
      result = described_class.call(boxset: boxset, card_data: card_data)
      expect(result[:name]).to eq('Lightning Bolt')
      expect(result[:card_type]).to eq('Instant')
      expect(result[:boxset]).to eq(boxset)
      expect(result[:is_token]).to be false
    end

    it 'includes card-specific attributes' do
      result = described_class.call(boxset: boxset, card_data: card_data)
      expect(result[:rarity]).to eq('common')
      expect(result[:mana_cost]).to eq('{R}')
      expect(result[:edhrec_rank]).to eq(5)
    end
  end

  context 'for a token' do
    it 'excludes card-specific attributes' do
      result = described_class.call(boxset: boxset, card_data: card_data, is_token: true)
      expect(result[:is_token]).to be true
      expect(result).not_to have_key(:rarity)
      expect(result).not_to have_key(:edhrec_rank)
    end
  end
end
