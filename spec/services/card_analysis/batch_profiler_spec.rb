require 'rails_helper'

RSpec.describe CardAnalysis::BatchProfiler, type: :service do
  let(:first_oracle_id) { SecureRandom.uuid }
  let(:second_oracle_id) { SecureRandom.uuid }

  let!(:card1) do
    create(:magic_card,
           scryfall_oracle_id: first_oracle_id,
           text: 'Destroy target creature.',
           card_type: 'Instant',
           is_token: false,
           card_side: nil)
  end

  let!(:card2) do
    create(:magic_card,
           scryfall_oracle_id: second_oracle_id,
           text: '{T}: Add {G}.',
           card_type: 'Creature - Elf Druid',
           is_token: false,
           card_side: nil)
  end

  let!(:token_card) do
    create(:magic_card,
           scryfall_oracle_id: SecureRandom.uuid,
           text: 'Flying',
           card_type: 'Token Creature - Angel',
           is_token: true,
           card_side: nil)
  end

  before do
    # Stub keyword/subtype associations to return empty relation
    empty_relation = Keyword.none
    empty_subtype_relation = SubType.none
    allow_any_instance_of(MagicCard).to receive(:keywords).and_return(empty_relation)
    allow_any_instance_of(MagicCard).to receive(:sub_types).and_return(empty_subtype_relation)
  end

  describe '#call' do
    it 'returns success result' do
      result = described_class.call
      expect(result[:success]).to be true
      expect(result[:processed]).to be >= 2
    end

    it 'creates card roles for profiled cards' do
      expect { described_class.call }.to change { CardRole.count }.by_at_least(1)
    end

    it 'skips token cards' do
      described_class.call
      expect(CardRole.for_oracle_id(token_card.scryfall_oracle_id)).to be_empty
    end

    it 'scopes to given oracle_ids' do
      result = described_class.call(oracle_ids: [first_oracle_id])
      expect(result[:processed]).to eq(1)
      expect(CardRole.for_oracle_id(first_oracle_id)).to be_present
    end

    it 'upserts on re-run without duplicating' do
      described_class.call
      initial_count = CardRole.count
      described_class.call
      expect(CardRole.count).to eq(initial_count)
    end
  end
end
