require 'rails_helper'

RSpec.describe PriceAlert, type: :model do
  let(:user) { create(:user) }
  let(:oracle_id) { SecureRandom.uuid }
  let(:card) { create(:magic_card, scryfall_oracle_id: oracle_id, normal_price: 10, foil_price: 30) }

  describe 'threshold validations' do
    it 'accepts a printing with a concrete finish' do
      expect(build(:price_alert, user: user, magic_card: card)).to be_valid
    end

    it 'accepts an oracle id with any finish' do
      alert = build(:price_alert, user: user, magic_card: nil, scryfall_oracle_id: oracle_id, finish: 'any')
      expect(alert).to be_valid
    end

    it 'refuses a printing watched in any finish' do
      alert = build(:price_alert, user: user, magic_card: card, finish: 'any')
      expect(alert).not_to be_valid
      expect(alert.errors[:finish]).to be_present
    end

    it 'refuses both a printing and an oracle id' do
      alert = build(:price_alert, user: user, magic_card: card, scryfall_oracle_id: oracle_id)
      expect(alert).not_to be_valid
    end

    it 'refuses neither a printing nor an oracle id' do
      expect(build(:price_alert, user: user, magic_card: nil)).not_to be_valid
    end

    it 'needs a threshold price' do
      alert = build(:price_alert, user: user, threshold_price: nil)
      expect(alert).not_to be_valid
      expect(alert.errors[:threshold_price]).to be_present
    end

    it 'refuses a movement direction' do
      alert = build(:price_alert, user: user, direction: 'up')
      expect(alert).not_to be_valid
      expect(alert.errors[:direction]).to be_present
    end

    it 'refuses a non-positive threshold' do
      expect(build(:price_alert, user: user, threshold_price: 0)).not_to be_valid
    end
  end

  describe 'movement rule validations' do
    it 'accepts a rule with a minimum move' do
      expect(build(:price_alert, :movement_rule, user: user)).to be_valid
    end

    it 'accepts a percent-only rule' do
      expect(build(:price_alert, :movement_rule, user: user, min_delta_amount: nil, min_delta_percent: 15)).to be_valid
    end

    it 'needs a minimum move in dollars or percent' do
      expect(build(:price_alert, :movement_rule, user: user, min_delta_amount: nil)).not_to be_valid
    end

    it 'needs a window' do
      alert = build(:price_alert, :movement_rule, user: user, window: 'monthly')
      expect(alert).not_to be_valid
      expect(alert.errors[:window]).to be_present
    end

    it 'refuses a threshold direction' do
      expect(build(:price_alert, :movement_rule, user: user, direction: 'above')).not_to be_valid
    end

    it 'can be narrowed to one of the user collections' do
      collection = create(:collection, user: user)
      expect(build(:price_alert, :movement_rule, user: user, collection: collection)).to be_valid
    end

    it 'refuses someone else collection' do
      alert = build(:price_alert, :movement_rule, user: user, collection: create(:collection))
      expect(alert).not_to be_valid
      expect(alert.errors[:collection]).to be_present
    end

    it 'is removed with its collection' do
      collection = create(:collection, user: user)
      create(:price_alert, :movement_rule, user: user, collection: collection)
      expect { collection.destroy }.to change(described_class, :count).by(-1)
    end
  end

  describe 'card override validations' do
    it 'accepts one per card and window' do
      create(:price_alert, :card_override, user: user, magic_card: card, window: 'daily')
      expect(build(:price_alert, :card_override, user: user, magic_card: card, window: 'weekly')).to be_valid
    end

    it 'refuses a second override for the same card and window' do
      create(:price_alert, :card_override, user: user, magic_card: card)
      expect(build(:price_alert, :card_override, user: user, magic_card: card)).not_to be_valid
    end

    it 'lets another user override the same card' do
      create(:price_alert, :card_override, user: user, magic_card: card)
      expect(build(:price_alert, :card_override, magic_card: card)).to be_valid
    end
  end

  describe 'scopes' do
    it 'tells rules, overrides and thresholds apart' do
      threshold = create(:price_alert, user: user)
      rule = create(:price_alert, :movement_rule, user: user)
      override = create(:price_alert, :card_override, user: user)
      create(:price_alert, user: user, active: false)

      expect(described_class.thresholds.active).to contain_exactly(threshold)
      expect(described_class.movement_rules).to contain_exactly(rule)
      expect(described_class.card_overrides).to contain_exactly(override)
    end
  end

  describe '#current_price' do
    it 'reads the printing price for its finish' do
      expect(build(:price_alert, magic_card: card, finish: 'foil').current_price).to eq(30)
    end

    context 'when watching an oracle id' do
      let(:alert) { build(:price_alert, magic_card: nil, scryfall_oracle_id: oracle_id, finish: finish) }
      let(:finish) { 'any' }

      before do
        card
        create(:magic_card, scryfall_oracle_id: oracle_id, normal_price: 4, foil_price: 0)
        create(:magic_card, scryfall_oracle_id: oracle_id, normal_price: 0, foil_price: 12)
        create(:magic_card, scryfall_oracle_id: SecureRandom.uuid, normal_price: 1, foil_price: 1)
      end

      it 'reads the cheapest priced printing of either finish' do
        expect(alert.current_price).to eq(4)
      end

      context 'with the foil finish' do
        let(:finish) { 'foil' }

        it 'skips unpriced foils' do
          expect(alert.current_price).to eq(12)
        end
      end

      context 'with the normal finish' do
        let(:finish) { 'normal' }

        it 'reads the cheapest non-foil' do
          expect(alert.current_price).to eq(4)
        end
      end

      it 'ignores back faces' do
        create(:magic_card, scryfall_oracle_id: oracle_id, card_side: 'b', normal_price: 1)
        expect(alert.current_price).to eq(4)
      end
    end

    it 'is nil when nothing is priced' do
      unpriced = create(:magic_card, normal_price: 0, foil_price: 0)
      expect(build(:price_alert, magic_card: unpriced).current_price).to be_nil
    end
  end

  describe 'last_side' do
    it 'starts above when the price is already past the threshold' do
      alert = create(:price_alert, user: user, magic_card: card, threshold_price: 8)
      expect(alert.last_side).to eq('above')
    end

    it 'starts below when the price has not reached it' do
      alert = create(:price_alert, user: user, magic_card: card, threshold_price: 25)
      expect(alert.last_side).to eq('below')
    end

    it 'counts landing on the threshold as above' do
      alert = create(:price_alert, user: user, magic_card: card, threshold_price: 10)
      expect(alert.last_side).to eq('above')
    end

    it 'stays empty when the card has no price' do
      unpriced = create(:magic_card, normal_price: 0)
      expect(create(:price_alert, user: user, magic_card: unpriced).last_side).to be_nil
    end

    it 'is recomputed when the threshold changes' do
      alert = create(:price_alert, user: user, magic_card: card, threshold_price: 25)
      alert.update!(threshold_price: 5)
      expect(alert.last_side).to eq('above')
    end

    it 'is left alone by unrelated saves' do
      alert = create(:price_alert, user: user, magic_card: card, threshold_price: 25)
      card.update!(normal_price: 40)
      alert.update!(active: false)
      expect(alert.last_side).to eq('below')
    end

    it 'is not set on movement alerts' do
      expect(create(:price_alert, :movement_rule, user: user).last_side).to be_nil
    end
  end

  describe 're-arming' do
    it 'is disarmed while the price sits on the alert direction' do
      expect(build(:price_alert, threshold_price: 20, direction: 'above', last_side: 'above')).to be_disarmed
      expect(build(:price_alert, threshold_price: 20, direction: 'above', last_side: 'below')).not_to be_disarmed
      expect(build(:price_alert, threshold_price: 20, direction: 'above', last_side: nil)).not_to be_disarmed
    end

    it 'puts the re-arm line the margin back from the threshold' do
      expect(build(:price_alert, threshold_price: 20, direction: 'above').rearm_price).to eq(19)
      expect(build(:price_alert, threshold_price: 20, direction: 'below').rearm_price).to eq(21)
    end

    it 're-arms only past the line, counting landing on it' do
      above = build(:price_alert, threshold_price: 20, direction: 'above')
      below = build(:price_alert, threshold_price: 20, direction: 'below')

      expect([above.rearms_at?(19.5), above.rearms_at?(19), above.rearms_at?(nil)]).to eq([false, true, false])
      expect([below.rearms_at?(20.5), below.rearms_at?(21)]).to eq([false, true])
    end
  end

  describe '.threshold_for_want' do
    it 'watches any printing for an any-printing want' do
      want = create(:want_list_item, user: user, magic_card: card, foil_preference: 'non_foil')
      alert = described_class.threshold_for_want(want, threshold_price: 5, direction: 'below')

      expect(alert).to be_valid
      expect(alert).to have_attributes(scryfall_oracle_id: oracle_id, magic_card_id: nil, finish: 'normal')
    end

    it 'watches the exact printing in a concrete finish' do
      want = create(:want_list_item, :specific_printing, user: user, magic_card: card)
      alert = described_class.threshold_for_want(want, threshold_price: 5, direction: 'below')

      expect(alert).to be_valid
      expect(alert).to have_attributes(magic_card_id: card.id, finish: 'normal')
    end
  end

  describe '.movement_rule_attributes' do
    # what CollectionStats::MoversTable hands the page, sort and all
    let(:filters) do
      { window: 'daily', direction: 'up', finish: 'both', min_delta: BigDecimal('5'), min_percent: nil,
        min_price: BigDecimal('2.5'), min_buylist: BigDecimal('0.25'), max_buylist: nil, rarity: %w[rare mythic],
        sort: 'name', dir: 'asc' }
    end

    it 'saves the filters as a movement rule, leaving sort and page out' do
      collection = create(:collection, user: user)

      expect(described_class.movement_rule_attributes(filters, collection_id: collection.id)).to eq(
        collection_id: collection.id, window: 'daily', direction: 'up', finish: 'any',
        min_delta_amount: BigDecimal('5'), min_delta_percent: nil, min_price: BigDecimal('2.5'),
        min_buylist_price: BigDecimal('0.25'), max_buylist_price: nil, rarities: %w[rare mythic]
      )
    end

    it 'rounds amounts to the cents they are stored as, and drops one that rounds to nothing' do
      attributes = described_class.movement_rule_attributes(filters.merge(min_delta: BigDecimal('5.555'),
                                                                          min_percent: BigDecimal('0.001')))

      expect(attributes).to include(min_delta_amount: BigDecimal('5.56'), min_delta_percent: nil)
    end

    it 'round-trips: the rule links back to the same movers table filters' do
      rule = user.price_alerts.create!(kind: 'movement', **described_class.movement_rule_attributes(filters))
      table = CollectionStats::MoversTable.new(collection_ids: [], filters: rule.movers_filters).call

      expect(table[:filters].except(:sort, :dir)).to eq(filters.except(:sort, :dir))
    end

    it 'finds the active rule already counting the same filters' do
      attributes = described_class.movement_rule_attributes(filters)
      rule = user.price_alerts.create!(kind: 'movement', **attributes)
      user.price_alerts.create!(kind: 'movement', **attributes, min_price: nil)

      expect(user.price_alerts.active.matching_rule(attributes)).to contain_exactly(rule)
    end
  end

  describe 'bands' do
    def band(**attributes)
      build(:price_alert, :band, user: user, **attributes)
    end

    it 'is valid going up from under its threshold, both ways, or down from over it' do
      expect(band).to be_valid
      expect(band(direction: 'both')).to be_valid
      expect(band(direction: 'below', from_price: 1.1)).to be_valid
    end

    it 'needs a from price on the right side of the threshold' do
      expect(band(from_price: 1.1)).not_to be_valid
      expect(band(from_price: 1)).not_to be_valid
      expect(band(direction: 'below')).not_to be_valid
      expect(band(direction: 'both', from_price: 1.1)).not_to be_valid
      expect(band(direction: 'sideways')).not_to be_valid
      expect(band(from_price: nil)).not_to be_valid
    end

    it 'watches no single card' do
      expect(band(magic_card: create(:magic_card))).not_to be_valid
      expect(band(window: 'daily')).not_to be_valid
    end

    it 'can narrow to one of its own collections only' do
      expect(band(collection: create(:collection, user: user))).to be_valid
      expect(band(collection: create(:collection))).not_to be_valid
    end

    it 'is back at its from price landing on it' do
      expect(band.returns_at?(BigDecimal('0.9'))).to be(true)
      expect(band.returns_at?(BigDecimal('0.91'))).to be(false)
      expect(band(direction: 'below', from_price: 1.1).returns_at?(BigDecimal('1.1'))).to be(true)
    end

    it 'names the way each line is crossed' do
      expect(band(direction: 'both')).to have_attributes(reach_move: 'up', return_move: 'down', two_way?: true)
      expect(band(direction: 'below', from_price: 1.1)).to have_attributes(reach_move: 'down', two_way?: false)
    end

    it 'reaches its threshold landing on it' do
      expect(band.reaches?(BigDecimal('1'))).to be(true)
      expect(band.reaches?(BigDecimal('0.99'))).to be(false)
      expect(band(direction: 'below', from_price: 1.1).reaches?(BigDecimal('0.99'))).to be(true)
    end
  end

  describe 'the buylist range' do
    def rule(**attributes)
      build(:price_alert, :movement_rule, user: user, **attributes)
    end

    it 'lets every card through with no range, even one CK is not buying' do
      expect(rule.buylist_in_range?(nil)).to be(true)
      expect(rule.buylist_in_range?(BigDecimal('0'))).to be(true)
    end

    it 'keeps a card between the ends, both included, and never one CK is not buying' do
      ranged = rule(min_buylist_price: 0.25, max_buylist_price: 2)

      expect(ranged.buylist_in_range?(BigDecimal('0.25'))).to be(true)
      expect(ranged.buylist_in_range?(BigDecimal('2'))).to be(true)
      expect(ranged.buylist_in_range?(BigDecimal('2.01'))).to be(false)
      expect(ranged.buylist_in_range?(BigDecimal('0'))).to be(false)
      expect(rule(max_buylist_price: 2).buylist_in_range?(BigDecimal('0'))).to be(false)
    end

    it 'needs the minimum no higher than the maximum' do
      expect(rule(min_buylist_price: 3, max_buylist_price: 2)).not_to be_valid
    end

    it 'is not something a threshold alert takes' do
      expect(build(:price_alert, user: user, min_buylist_price: 1)).not_to be_valid
    end

    it 'rides along in the movers filters a rule links to' do
      expect(rule(min_buylist_price: 0.25).movers_filters).to include(min_buylist: '0.25')
    end
  end

  describe 'rarities' do
    def rule(**attributes)
      build(:price_alert, :movement_rule, user: user, **attributes)
    end

    it 'keeps them in the movers table order, dropping blanks and unknown ones' do
      expect(rule(rarities: ['', 'mythic', 'bogus', 'common']).rarities).to eq(%w[common mythic])
    end

    it 'finds no rule, rather than raising, when none matches' do
      filters = { window: 'daily', direction: 'both', finish: 'both', min_delta: BigDecimal('5'),
                  rarity: %w[rare mythic] }

      expect(described_class.matching_rule(described_class.movement_rule_attributes(filters))).to be_empty
    end

    it 'finds a rule by a pick of one rarity, or of none, and not by a different pick' do
      common = rule(rarities: %w[common]).tap(&:save!)
      every = rule(rarities: []).tap(&:save!)
      filters = { window: 'daily', direction: 'both', finish: 'both', min_delta: BigDecimal('5') }

      expect(described_class.matching_rule(described_class.movement_rule_attributes(filters.merge(rarity: %w[common]))))
        .to contain_exactly(common)
      expect(described_class.matching_rule(described_class.movement_rule_attributes(filters))).to contain_exactly(every)
    end

    it 'finds the rule saved from the same pick' do
      saved = rule(rarities: %w[rare mythic])
      saved.save!

      filters = { window: saved.window, direction: saved.direction, finish: 'both',
                  min_delta: saved.min_delta_amount, rarity: %w[mythic rare] }

      expect(described_class.matching_rule(described_class.movement_rule_attributes(filters)))
        .to contain_exactly(saved)
    end

    it 'rides along in the movers filters a rule links to, and stays off with none picked' do
      expect(rule(rarities: %w[rare]).movers_filters).to include(rarity: %w[rare])
      expect(rule.movers_filters).not_to have_key(:rarity)
    end

    it 'is not something a threshold alert or a band takes' do
      expect(build(:price_alert, user: user, rarities: %w[rare])).not_to be_valid
      expect(build(:price_alert, :band, user: user, rarities: %w[rare])).not_to be_valid
    end
  end
end
