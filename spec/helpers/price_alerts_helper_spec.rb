require 'rails_helper'

RSpec.describe PriceAlertsHelper, type: :helper do
  let(:user) { create(:user) }
  let(:card) { create(:magic_card) }

  describe '#price_alert_condition' do
    it 'reads a threshold as direction, price and finish' do
      alert = build(:price_alert, direction: 'above', threshold_price: 20, finish: 'foil')

      expect(helper.price_alert_condition(alert)).to eq('Above $20.00 (foil)')
    end

    it 'reads a movement rule as window, minimums and direction' do
      alert = build(:price_alert, :movement_rule, window: 'weekly', min_delta_amount: 5, min_delta_percent: 15)

      expect(helper.price_alert_condition(alert)).to eq('Weekly, ±$5 and ±15%, up or down')
    end

    it 'adds the finish and the minimum card price when a rule narrows them' do
      alert = build(:price_alert, :movement_rule, window: 'daily', direction: 'down', min_delta_amount: 2.5,
                                                  finish: 'foil', min_price: 3)

      expect(helper.price_alert_condition(alert)).to eq('Daily, -$2.50, down, foil, cards $3.00+')
    end
  end

  describe '#price_alert_watched?' do
    # current_user comes from the controller, so the helper under test has to be handed one
    before do
      someone = user
      helper.define_singleton_method(:current_user) { someone }
    end

    it 'lights only for active thresholds on the same card' do
      create(:price_alert, user: user, magic_card: card)
      create(:price_alert, user: user, magic_card: create(:magic_card), active: false)
      create(:price_alert, :card_override, user: user, magic_card: create(:magic_card))
      oracle_id = SecureRandom.uuid
      create(:price_alert, user: user, magic_card: nil, scryfall_oracle_id: oracle_id, finish: 'any')

      watched = PriceAlert.where(user: user).order(:id).map do |alert|
        helper.price_alert_watched?(helper.price_alert_bell_key(magic_card_id: alert.magic_card_id,
                                                                scryfall_oracle_id: alert.scryfall_oracle_id))
      end

      expect(watched).to eq([true, false, false, true])
    end
  end
end
