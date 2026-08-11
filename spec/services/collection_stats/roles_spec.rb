require 'rails_helper'

RSpec.describe CollectionStats::Roles, type: :service do
  subject(:result) { described_class.call(collection_ids: [collection.id]) }

  let(:collection) { create(:collection) }

  # roles are keyed by oracle id, so every helper here takes one explicitly - the magic_card
  # factory leaves the column nil and a nil oracle id can never match a role
  def own(oracle_id, quantity: 1, price: 10, **overrides)
    card = create(:magic_card, scryfall_oracle_id: oracle_id, normal_price: price, **overrides)
    create(:collection_magic_card, collection: collection, magic_card: card, quantity: quantity)
    card
  end

  def tag(oracle_id, role, effect, confidence: 1.0)
    create(:card_role, scryfall_oracle_id: oracle_id, role: role, effect: effect,
                       confidence: confidence)
  end

  def role_row(role)
    result[:roles].find { |row| row[:role] == role }
  end

  def chip(label)
    result[:effects].find { |row| row[:label] == label }
  end

  let(:oracle) { SecureRandom.uuid }

  describe 'the uuid to string join' do
    # magic_cards.scryfall_oracle_id is uuid and card_roles.scryfall_oracle_id is a string. If the
    # cast were wrong or missing this whole panel would silently return zeros.
    it 'matches a card to its role across the type boundary' do
      own(oracle, quantity: 2, price: 25)
      tag(oracle, 'removal', 'targeted_removal')

      expect(role_row('removal')[:copies]).to eq(2)
      expect(role_row('removal')[:value]).to eq(50)
    end

    it 'leaves cards with no oracle id out of the role counts' do
      card = create(:magic_card, scryfall_oracle_id: nil)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1)

      expect(result[:roles].sum { |row| row[:copies] }).to eq(0)
    end
  end

  describe 'printings of the same card' do
    # the reason owned_by_oracle exists: without it a card held in three printings would be three
    # removal cards
    it 'counts the role once however many printings are owned' do
      own(oracle, quantity: 1)
      own(oracle, quantity: 2)
      tag(oracle, 'removal', 'targeted_removal')

      expect(role_row('removal')[:cards]).to eq(1)
    end

    it 'still adds up every copy across those printings' do
      own(oracle, quantity: 1, price: 10)
      own(oracle, quantity: 2, price: 5)
      tag(oracle, 'removal', 'targeted_removal')

      expect(role_row('removal')[:copies]).to eq(3)
      expect(role_row('removal')[:value]).to eq(20)
    end

    # a card can carry several effects inside one role - a spell tagged both draw and cantrip is
    # one card_draw card, not two
    it 'counts the role once when the card has several effects inside it' do
      own(oracle, quantity: 2, price: 10)
      tag(oracle, 'card_draw', 'draw')
      tag(oracle, 'card_draw', 'cantrip')

      expect(role_row('card_draw')[:copies]).to eq(2)
      expect(role_row('card_draw')[:cards]).to eq(1)
      expect(role_row('card_draw')[:value]).to eq(20)
    end
  end

  describe 'a card that does several things' do
    it 'appears under every role it carries' do
      own(oracle, quantity: 1, price: 10)
      tag(oracle, 'removal', 'targeted_removal')
      tag(oracle, 'card_draw', 'draw')
      tag(oracle, 'ramp', 'ritual')

      expect(role_row('removal')[:copies]).to eq(1)
      expect(role_row('card_draw')[:copies]).to eq(1)
      expect(role_row('ramp')[:copies]).to eq(1)
    end

    # shares are a share of role slots rather than of cards, so the bars fill the panel instead of
    # overflowing it - the same trade CardTypes makes
    it 'splits shares across a total of 100%' do
      own(oracle)
      tag(oracle, 'removal', 'targeted_removal')
      tag(oracle, 'card_draw', 'draw')

      expect(result[:roles].sum { |row| row[:share] }).to eq(100.0)
    end
  end

  describe 'confidence' do
    it 'ignores anything the profiler was not sure about' do
      own(oracle)
      tag(oracle, 'card_draw', 'card_selection', confidence: 0.5)

      expect(role_row('card_draw')[:copies]).to eq(0)
    end

    it 'keeps a match sitting exactly on the threshold' do
      own(oracle)
      tag(oracle, 'card_draw', 'draw', confidence: CardRole::HIGH_CONFIDENCE)

      expect(role_row('card_draw')[:copies]).to eq(1)
    end

    it 'still counts the role when only one of its effects is confident' do
      own(oracle)
      tag(oracle, 'removal', 'targeted_removal', confidence: 1.0)
      tag(oracle, 'removal', 'board_wipe', confidence: 0.4)

      expect(role_row('removal')[:cards]).to eq(1)
    end
  end

  describe 'coverage' do
    it 'counts an unprofiled printing in the denominator but not in the roles' do
      own(oracle)
      tag(oracle, 'removal', 'targeted_removal')
      own(SecureRandom.uuid)

      expect(result[:total_printings]).to eq(2)
      expect(result[:covered_printings]).to eq(1)
      expect(result[:coverage_share]).to eq(50.0)
      expect(result[:roles].sum { |row| row[:cards] }).to eq(1)
    end

    it 'counts every printing of a profiled card as covered' do
      own(oracle)
      own(oracle)
      tag(oracle, 'removal', 'targeted_removal')

      expect(result[:total_printings]).to eq(2)
      expect(result[:covered_printings]).to eq(2)
    end

    # the low-confidence rows are excluded from the counts, so they must not quietly prop up the
    # coverage figure either
    it 'does not treat a low-confidence match as coverage' do
      own(oracle)
      tag(oracle, 'card_draw', 'card_selection', confidence: 0.5)

      expect(result[:covered_printings]).to eq(0)
      expect(result[:coverage_share]).to eq(0.0)
    end

    it 'reports no coverage rather than dividing by zero when nothing is owned' do
      expect(result[:coverage_share]).to eq(0.0)
      expect(result[:total_printings]).to eq(0)
    end
  end

  describe 'the role rows' do
    it 'lists every role the app knows about' do
      expect(result[:roles].map { |row| row[:role] }).to match_array(CardRole::ROLES)
    end

    it 'sorts by copies, heaviest first' do
      draw = SecureRandom.uuid
      own(draw, quantity: 5)
      tag(draw, 'card_draw', 'draw')
      own(oracle, quantity: 1)
      tag(oracle, 'removal', 'targeted_removal')

      expect(result[:roles].first(2).map { |row| row[:role] }).to eq(%w[card_draw removal])
    end

    it 'labels roles for reading rather than for the database' do
      expect(role_row('lands_matter')[:label]).to eq('Lands Matter')
    end

    it 'ignores staged deck-builder rows' do
      card = create(:magic_card, scryfall_oracle_id: oracle)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1,
                                     staged: true)
      tag(oracle, 'removal', 'targeted_removal')

      expect(role_row('removal')[:copies]).to eq(0)
      expect(result[:total_printings]).to eq(0)
    end
  end

  describe 'notable effects' do
    it 'reports every curated chip whether or not anything matched' do
      expect(result[:effects].map { |row| row[:label] })
        .to eq(described_class::NOTABLE_EFFECTS.map { |chip| chip[:label] })
    end

    it 'counts copies and value against the chip' do
      own(oracle, quantity: 3, price: 4)
      tag(oracle, 'protection', 'counterspell')

      expect(chip('Counterspells')[:copies]).to eq(3)
      expect(chip('Counterspells')[:value]).to eq(12)
    end

    # a shock land is also a dual land, and BatchProfiler tags it as both. One chip covers both
    # effects, so without the DISTINCT the card would be counted twice inside a single chip.
    it 'counts a card once when it matches a chip through two effects' do
      own(oracle, quantity: 2, price: 10)
      tag(oracle, 'manabase', 'shock_land')
      tag(oracle, 'manabase', 'dual_land')

      expect(chip('Fetches / Shocks / Duals')[:copies]).to eq(2)
      expect(chip('Fetches / Shocks / Duals')[:cards]).to eq(1)
      expect(chip('Fetches / Shocks / Duals')[:value]).to eq(20)
    end

    it 'keeps effects inside the same role in separate chips' do
      own(oracle, quantity: 1)
      tag(oracle, 'removal', 'board_wipe')

      expect(chip('Board Wipes')[:copies]).to eq(1)
      expect(chip('Spot Removal')[:copies]).to eq(0)
    end

    it 'ignores effects outside the curated set' do
      own(oracle, quantity: 1)
      tag(oracle, 'evasion', 'flying_grant')

      expect(result[:effects].sum { |row| row[:copies] }).to eq(0)
      expect(role_row('evasion')[:copies]).to eq(1)
    end

    it 'ignores a low-confidence match' do
      own(oracle, quantity: 1)
      tag(oracle, 'ramp', 'ritual', confidence: 0.5)

      expect(chip('Rituals')[:copies]).to eq(0)
    end

    it 'only names effects the profiler can actually emit' do
      described_class::NOTABLE_EFFECTS.each do |chip|
        expect(CardRole::EFFECTS.fetch(chip[:role])).to include(*chip[:effects])
      end
    end
  end

  it 'returns empty results and runs no queries when there are no collections' do
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
    end
    empty = described_class.call(collection_ids: [])
    ActiveSupport::Notifications.unsubscribe(subscriber)

    expect(empty).to eq(described_class::EMPTY)
    expect(queries).to be_empty
  end
end
