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
      'isReserved' => true,
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
      expect(result[:is_reserved]).to be true
    end

    describe 'flavor_name' do
      def flavor_name(extra)
        described_class.call(boxset: boxset, card_data: card_data.merge(extra))[:flavor_name]
      end

      it 'is nil for a card with only its own name' do
        expect(flavor_name('printedName' => 'Lightning Bolt')).to be_nil
      end

      it 'reads flavorName' do
        expect(flavor_name('flavorName' => 'Zap')).to eq('Zap')
      end

      it "prefers the face's own over the whole card's" do
        expect(flavor_name('flavorName' => 'Zap // Zop', 'faceFlavorName' => 'Zap')).to eq('Zap')
      end

      # some Secret Lair drops carry the alternate name only as printedName
      it 'falls back to a printedName that differs from the real name' do
        expect(flavor_name('printedName' => 'Zap')).to eq('Zap')
      end

      it 'ignores a facePrintedName that repeats the face name' do
        expect(flavor_name('name' => 'Fire // Ice', 'faceName' => 'Fire', 'facePrintedName' => 'Fire')).to be_nil
      end
    end

    # mtgjson omits isReserved entirely rather than sending false, and is_reserved is NOT NULL, so
    # passing the missing key straight through would blow up the insert on almost every card
    it 'reads a missing isReserved as false rather than nil' do
      result = described_class.call(boxset: boxset, card_data: card_data.except('isReserved'))

      expect(result[:is_reserved]).to be false
    end
  end

  context 'for a token' do
    it 'excludes card-specific attributes' do
      result = described_class.call(boxset: boxset, card_data: card_data, is_token: true)
      expect(result[:is_token]).to be true
      expect(result).not_to have_key(:rarity)
      expect(result).not_to have_key(:edhrec_rank)
      expect(result).not_to have_key(:is_reserved)
    end
  end
end
