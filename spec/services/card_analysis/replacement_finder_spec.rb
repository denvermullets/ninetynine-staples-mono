require 'rails_helper'

RSpec.describe CardAnalysis::ReplacementFinder, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'commander_deck') }
  let(:other_collection) { create(:collection, user: user, name: 'Binder') }

  let(:commander_legality) { Legality.find_or_create_by!(name: 'commander') }
  let(:source_oracle_id) { SecureRandom.uuid }
  let(:source_card) do
    create(:magic_card, scryfall_oracle_id: source_oracle_id, card_side: nil)
  end

  let!(:deck_card) do
    create(:collection_magic_card, collection: deck, magic_card: source_card)
  end

  def make_commander_legal(card)
    MagicCardLegality.find_or_create_by!(
      magic_card: card, legality: commander_legality, status: 'Legal'
    )
  end

  def create_card_with_roles(oracle_id:, roles:, card_side: nil)
    card = create(:magic_card, scryfall_oracle_id: oracle_id, card_side: card_side)
    make_commander_legal(card)
    roles.each do |role, effect, confidence|
      CardRole.create!(
        scryfall_oracle_id: oracle_id,
        role: role, effect: effect,
        confidence: confidence, source: 'test'
      )
    end
    card
  end

  describe '#call' do
    it 'returns empty candidates when card has no roles' do
      result = described_class.call(
        magic_card: source_card, deck: deck, user: user
      )
      expect(result[:roles]).to be_empty
      expect(result[:candidates]).to be_empty
    end

    context 'with source card roles' do
      before do
        CardRole.create!(
          scryfall_oracle_id: source_oracle_id,
          role: 'removal', effect: 'targeted_removal',
          confidence: 0.9, source: 'test'
        )
      end

      it 'returns candidates sharing role/effect pairs' do
        candidate_oid = SecureRandom.uuid
        create_card_with_roles(
          oracle_id: candidate_oid,
          roles: [['removal', 'targeted_removal', 0.85]]
        )

        result = described_class.call(
          magic_card: source_card, deck: deck, user: user
        )
        expect(result[:candidates].size).to eq(1)
        expect(result[:candidates].first[:magic_card].scryfall_oracle_id).to eq(candidate_oid)
      end

      it 'excludes cards already in deck' do
        in_deck_oid = SecureRandom.uuid
        in_deck_card = create_card_with_roles(
          oracle_id: in_deck_oid,
          roles: [['removal', 'targeted_removal', 0.9]]
        )
        create(:collection_magic_card, collection: deck, magic_card: in_deck_card)

        result = described_class.call(
          magic_card: source_card, deck: deck, user: user
        )
        oracle_ids = result[:candidates].map { |c| c[:magic_card].scryfall_oracle_id }
        expect(oracle_ids).not_to include(in_deck_oid)
      end

      it 'excludes the source card itself' do
        result = described_class.call(
          magic_card: source_card, deck: deck, user: user
        )
        oracle_ids = result[:candidates].map { |c| c[:magic_card].scryfall_oracle_id }
        expect(oracle_ids).not_to include(source_oracle_id)
      end

      it 'returns matched_roles per candidate' do
        candidate_oid = SecureRandom.uuid
        create_card_with_roles(
          oracle_id: candidate_oid,
          roles: [['removal', 'targeted_removal', 0.85]]
        )

        result = described_class.call(
          magic_card: source_card, deck: deck, user: user
        )
        matched = result[:candidates].first[:matched_roles]
        expect(matched).to include({ role: 'removal', effect: 'targeted_removal' })
      end
    end

    context 'scoring and sorting' do
      before do
        CardRole.create!(
          scryfall_oracle_id: source_oracle_id,
          role: 'removal', effect: 'targeted_removal',
          confidence: 0.9, source: 'test'
        )
        CardRole.create!(
          scryfall_oracle_id: source_oracle_id,
          role: 'removal', effect: 'exile_removal',
          confidence: 0.8, source: 'test'
        )
      end

      it 'higher-scoring candidates rank first' do
        low_oid = SecureRandom.uuid
        create_card_with_roles(
          oracle_id: low_oid,
          roles: [['removal', 'targeted_removal', 0.5]]
        )

        high_oid = SecureRandom.uuid
        create_card_with_roles(
          oracle_id: high_oid,
          roles: [
            ['removal', 'targeted_removal', 0.95],
            ['removal', 'exile_removal', 0.9]
          ]
        )

        result = described_class.call(
          magic_card: source_card, deck: deck, user: user
        )
        oracle_ids = result[:candidates].map { |c| c[:magic_card].scryfall_oracle_id }
        expect(oracle_ids).to eq([high_oid, low_oid])
      end

      it 'owned cards sort before unowned cards' do
        unowned_oid = SecureRandom.uuid
        create_card_with_roles(
          oracle_id: unowned_oid,
          roles: [
            ['removal', 'targeted_removal', 0.95],
            ['removal', 'exile_removal', 0.95]
          ]
        )

        owned_oid = SecureRandom.uuid
        owned_card = create_card_with_roles(
          oracle_id: owned_oid,
          roles: [['removal', 'targeted_removal', 0.5]]
        )
        create(:collection_magic_card,
               collection: other_collection,
               magic_card: owned_card, quantity: 2)

        result = described_class.call(
          magic_card: source_card, deck: deck, user: user
        )
        oracle_ids = result[:candidates].map { |c| c[:magic_card].scryfall_oracle_id }
        expect(oracle_ids.first).to eq(owned_oid)
      end

      it 'marks owned candidates with owned: true and available count' do
        owned_oid = SecureRandom.uuid
        owned_card = create_card_with_roles(
          oracle_id: owned_oid,
          roles: [['removal', 'targeted_removal', 0.9]]
        )
        create(:collection_magic_card,
               collection: other_collection,
               magic_card: owned_card, quantity: 3)

        result = described_class.call(
          magic_card: source_card, deck: deck, user: user
        )
        candidate = result[:candidates].find { |c| c[:magic_card].scryfall_oracle_id == owned_oid }
        expect(candidate[:owned]).to be true
        expect(candidate[:available]).to eq(3)
        expect(candidate[:card_type]).to eq(:regular)
      end

      it 'returns flattened entries per card type for owned candidates' do
        owned_oid = SecureRandom.uuid
        owned_card = create_card_with_roles(
          oracle_id: owned_oid,
          roles: [['removal', 'targeted_removal', 0.9]]
        )
        create(:collection_magic_card,
               collection: other_collection,
               magic_card: owned_card, quantity: 2, foil_quantity: 1)

        result = described_class.call(
          magic_card: source_card, deck: deck, user: user
        )
        entries = result[:candidates].select { |c| c[:magic_card].scryfall_oracle_id == owned_oid }
        expect(entries.length).to eq(2)

        regular = entries.find { |c| c[:card_type] == :regular }
        expect(regular[:collection_name]).to eq('Binder')
        expect(regular[:collection_id]).to eq(other_collection.id)
        expect(regular[:magic_card_id]).to eq(owned_card.id)
        expect(regular[:available]).to eq(2)

        foil = entries.find { |c| c[:card_type] == :foil }
        expect(foil[:available]).to eq(1)
      end
    end

    context 'color identity filtering' do
      let(:green) { Color.find_or_create_by!(name: 'G') }
      let(:red) { Color.find_or_create_by!(name: 'R') }

      let(:commander_card) do
        card = create(:magic_card, scryfall_oracle_id: SecureRandom.uuid,
                                   can_be_commander: true, card_side: nil)
        MagicCardColorIdent.create!(magic_card: card, color: green)
        card
      end

      before do
        create(:collection_magic_card,
               collection: deck, magic_card: commander_card,
               board_type: 'commander')

        CardRole.create!(
          scryfall_oracle_id: source_oracle_id,
          role: 'ramp', effect: 'mana_dork',
          confidence: 0.9, source: 'test'
        )
      end

      it 'excludes candidates outside commander color identity' do
        off_color_oid = SecureRandom.uuid
        off_color_card = create_card_with_roles(
          oracle_id: off_color_oid,
          roles: [['ramp', 'mana_dork', 0.9]]
        )
        MagicCardColorIdent.create!(magic_card: off_color_card, color: red)

        result = described_class.call(
          magic_card: source_card, deck: deck, user: user
        )
        oracle_ids = result[:candidates].map { |c| c[:magic_card].scryfall_oracle_id }
        expect(oracle_ids).not_to include(off_color_oid)
      end

      it 'includes candidates within commander color identity' do
        on_color_oid = SecureRandom.uuid
        on_color_card = create_card_with_roles(
          oracle_id: on_color_oid,
          roles: [['ramp', 'mana_dork', 0.9]]
        )
        MagicCardColorIdent.create!(magic_card: on_color_card, color: green)

        result = described_class.call(
          magic_card: source_card, deck: deck, user: user
        )
        oracle_ids = result[:candidates].map { |c| c[:magic_card].scryfall_oracle_id }
        expect(oracle_ids).to include(on_color_oid)
      end

      it 'includes colorless candidates' do
        colorless_oid = SecureRandom.uuid
        create_card_with_roles(
          oracle_id: colorless_oid,
          roles: [['ramp', 'mana_dork', 0.9]]
        )

        result = described_class.call(
          magic_card: source_card, deck: deck, user: user
        )
        oracle_ids = result[:candidates].map { |c| c[:magic_card].scryfall_oracle_id }
        expect(oracle_ids).to include(colorless_oid)
      end
    end

    context 'without commanders' do
      before do
        CardRole.create!(
          scryfall_oracle_id: source_oracle_id,
          role: 'removal', effect: 'targeted_removal',
          confidence: 0.9, source: 'test'
        )
      end

      it 'skips color filtering when no commander is set' do
        red = Color.find_or_create_by!(name: 'R')
        red_oid = SecureRandom.uuid
        red_card = create_card_with_roles(
          oracle_id: red_oid,
          roles: [['removal', 'targeted_removal', 0.9]]
        )
        MagicCardColorIdent.create!(magic_card: red_card, color: red)

        result = described_class.call(
          magic_card: source_card, deck: deck, user: user
        )
        oracle_ids = result[:candidates].map { |c| c[:magic_card].scryfall_oracle_id }
        expect(oracle_ids).to include(red_oid)
      end
    end

    context 'EDHREC rank blending' do
      before do
        CardRole.create!(
          scryfall_oracle_id: source_oracle_id,
          role: 'removal', effect: 'targeted_removal',
          confidence: 0.9, source: 'test'
        )
      end

      it 'boosts score for higher-ranked (lower edhrec_rank) cards' do
        popular_oid = SecureRandom.uuid
        popular_card = create_card_with_roles(
          oracle_id: popular_oid,
          roles: [['removal', 'targeted_removal', 0.8]]
        )
        popular_card.update!(edhrec_rank: 100)

        unpopular_oid = SecureRandom.uuid
        unpopular_card = create_card_with_roles(
          oracle_id: unpopular_oid,
          roles: [['removal', 'targeted_removal', 0.8]]
        )
        unpopular_card.update!(edhrec_rank: 50_000)

        result = described_class.call(
          magic_card: source_card, deck: deck, user: user
        )
        popular_candidate = result[:candidates].find { |c| c[:magic_card].scryfall_oracle_id == popular_oid }
        unpopular_candidate = result[:candidates].find { |c| c[:magic_card].scryfall_oracle_id == unpopular_oid }

        expect(popular_candidate[:score]).to be > unpopular_candidate[:score]
      end

      it 'handles candidates with nil edhrec_rank gracefully' do
        no_rank_oid = SecureRandom.uuid
        create_card_with_roles(
          oracle_id: no_rank_oid,
          roles: [['removal', 'targeted_removal', 0.8]]
        )

        ranked_oid = SecureRandom.uuid
        ranked_card = create_card_with_roles(
          oracle_id: ranked_oid,
          roles: [['removal', 'targeted_removal', 0.8]]
        )
        ranked_card.update!(edhrec_rank: 500)

        result = described_class.call(
          magic_card: source_card, deck: deck, user: user
        )
        expect(result[:candidates].size).to eq(2)
      end
    end

    it 'limits to specified count' do
      CardRole.create!(
        scryfall_oracle_id: source_oracle_id,
        role: 'removal', effect: 'targeted_removal',
        confidence: 0.9, source: 'test'
      )

      3.times do
        create_card_with_roles(
          oracle_id: SecureRandom.uuid,
          roles: [['removal', 'targeted_removal', 0.8]]
        )
      end

      result = described_class.call(
        magic_card: source_card, deck: deck, user: user, limit: 2
      )
      expect(result[:candidates].size).to eq(2)
    end
  end
end
