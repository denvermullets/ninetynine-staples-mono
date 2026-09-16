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

  describe 'Scryfall Tagger tags' do
    let(:spot_removal) { create(:oracle_tag, slug: 'spot-removal') }
    let(:doom_blade) { create(:oracle_tag, slug: 'doom-blade') }
    let(:mana_rock) { create(:oracle_tag, slug: 'mana-rock') }

    # no pattern rule fires on this text, so every role it gets comes from its tags
    let!(:silent_card) do
      create(:magic_card, scryfall_oracle_id: SecureRandom.uuid, text: 'Nothing a rule would read.',
                          card_type: 'Artifact', is_token: false, card_side: nil)
    end

    def roles_for(card)
      CardRole.for_oracle_id(card.scryfall_oracle_id).pluck(:role, :effect, :confidence, :source)
    end

    before do
      OracleTagAncestor.create!(ancestor: spot_removal, descendant: doom_blade, depth: 1)
    end

    it 'maps a tag through the hierarchy into a tagger role at full confidence' do
      create(:card_oracle_tag, oracle_tag: doom_blade, scryfall_oracle_id: card1.scryfall_oracle_id)

      described_class.call(oracle_ids: [first_oracle_id])

      expect(roles_for(card1)).to include(['removal', 'targeted_removal', 1.0, 'tagger'])
    end

    it 'keeps the tagger row on a re-run even though a pattern rule also matches' do
      create(:card_oracle_tag, oracle_tag: doom_blade, scryfall_oracle_id: card1.scryfall_oracle_id)

      2.times { described_class.call(oracle_ids: [first_oracle_id]) }

      expect(roles_for(card1)).to include(['removal', 'targeted_removal', 1.0, 'tagger'])
    end

    # a retracted tag must not leave its 1.0 role behind
    it 'removes the role when the tagging goes away' do
      tagging = create(:card_oracle_tag, oracle_tag: mana_rock, scryfall_oracle_id: silent_card.scryfall_oracle_id)
      described_class.call(oracle_ids: [silent_card.scryfall_oracle_id])
      expect(roles_for(silent_card)).to eq([['ramp', 'mana_rock', 1.0, 'tagger']])

      tagging.destroy!
      described_class.call(oracle_ids: [silent_card.scryfall_oracle_id])

      expect(roles_for(silent_card)).to be_empty
    end

    it 'ignores a disabled tag' do
      mana_rock.update!(disabled: true)
      create(:card_oracle_tag, oracle_tag: mana_rock, scryfall_oracle_id: silent_card.scryfall_oracle_id)

      described_class.call(oracle_ids: [silent_card.scryfall_oracle_id])

      expect(roles_for(silent_card)).to be_empty
    end

    # user tags are unmoderated and TaggerDetector writes at 1.0
    it 'ignores tags users added' do
      create(:card_oracle_tag, :by_user, oracle_tag: mana_rock, scryfall_oracle_id: silent_card.scryfall_oracle_id)

      described_class.call(oracle_ids: [silent_card.scryfall_oracle_id])

      expect(roles_for(silent_card)).to be_empty
    end
  end
end
