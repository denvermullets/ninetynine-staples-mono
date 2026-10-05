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
end
