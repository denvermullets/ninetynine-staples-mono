require 'rails_helper'

RSpec.describe EvaluatePriceAlerts, type: :job do
  let(:user) { create(:user) }
  let(:today) { '2026-10-05' }
  let(:tomorrow) { '2026-10-06' }

  def evaluate(date = today)
    described_class.perform_now(date)
  end

  def notifications
    user.notifications.reload
  end

  describe 'threshold alerts' do
    let(:card) { create(:magic_card, name: 'Sheoldred', normal_price: 10, foil_price: 30) }
    let!(:alert) { create(:price_alert, user: user, magic_card: card, threshold_price: 20, direction: 'above') }

    it 'fires when the price crosses into the alert direction' do
      card.update!(normal_price: 25)

      expect { evaluate }.to change(Notification, :count).by(1)

      notification = notifications.last
      expect(notification).to have_attributes(kind: 'price_threshold_crossed', notifiable: alert)
      expect(notification.payload).to eq('card' => 'Sheoldred', 'direction' => 'above',
                                         'threshold' => '$20.00', 'price' => '$25.00')
      expect(alert.reload).to have_attributes(last_side: 'above', last_evaluated_on: Date.parse(today))
      expect(alert.last_fired_at).to be_present
    end

    it 'does not fire on the first evaluation, only learns the side' do
      alert.update_columns(last_side: nil)
      card.update!(normal_price: 25)

      expect { evaluate }.not_to change(Notification, :count)
      expect(alert.reload.last_side).to eq('above')
    end

    it 'does not fire again while the price stays across' do
      card.update!(normal_price: 25)
      evaluate
      card.update!(normal_price: 30)

      expect { evaluate(tomorrow) }.not_to change(Notification, :count)
    end

    it 'fires again after dropping back and crossing again' do
      card.update!(normal_price: 25)
      evaluate
      card.update!(normal_price: 15)
      evaluate(tomorrow)
      card.update!(normal_price: 22)

      expect { evaluate('2026-10-07') }.to change(Notification, :count).by(1)
    end

    it 'does not fire when crossing away from the alert direction' do
      alert.update_columns(last_side: 'above')

      expect { evaluate }.not_to change(Notification, :count)
      expect(alert.reload.last_side).to eq('below')
    end

    it 'skips a price of 0 as no data, keeping the side it had' do
      card.update!(normal_price: 0)

      expect { evaluate }.not_to change(Notification, :count)
      expect(alert.reload).to have_attributes(last_side: 'below', last_evaluated_on: Date.parse(today))
    end

    it 'ignores an inactive alert' do
      alert.update!(active: false)
      card.update!(normal_price: 25)

      expect { evaluate }.not_to change(Notification, :count)
    end
  end

  describe 'oracle threshold alerts' do
    let(:oracle_id) { SecureRandom.uuid }
    let!(:dear) do
      create(:magic_card, name: 'Ragavan', scryfall_oracle_id: oracle_id, normal_price: 60, foil_price: 90)
    end
    let!(:cheap) do
      create(:magic_card, name: 'Ragavan', scryfall_oracle_id: oracle_id, normal_price: 50, foil_price: 0)
    end
    let!(:alert) do
      create(:price_alert, user: user, magic_card: nil, scryfall_oracle_id: oracle_id, finish: 'any',
                           threshold_price: 40, direction: 'below')
    end

    it 'watches the cheapest priced printing' do
      cheap.update!(normal_price: 35)

      expect { evaluate }.to change(Notification, :count).by(1)
      expect(notifications.last.payload).to include('card' => 'Ragavan', 'price' => '$35.00')
    end

    it 'never takes an unpriced printing for the cheapest' do
      alert.update!(finish: 'foil', threshold_price: 100, direction: 'below')
      alert.update_columns(last_side: 'above')

      expect { evaluate }.to change(Notification, :count).by(1)
      expect(notifications.last.payload['price']).to eq('$90.00')
    end
  end

  describe 'movement rules' do
    let(:collection) { create(:collection, user: user) }
    let!(:rule) { create(:price_alert, :movement_rule, user: user, window: 'daily', min_delta_amount: 5) }

    # price_change_daily_normal is a percentage: a $110 card up 10% gained $10 today
    def own(name, price: 110, change: 10)
      card = create(:magic_card, name: name, normal_price: price, price_change_daily_normal: change)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1)
      card
    end

    it 'sends one notification for every card that moved, stating the count' do
      own('Big Riser')
      own('Big Faller', price: 50, change: -50)
      own('Small Riser', price: 101, change: 1)

      expect { evaluate }.to change(Notification, :count).by(1)

      notification = notifications.last
      expect(notification).to have_attributes(kind: 'price_movement', notifiable: rule)
      expect(notification.payload).to include('subject' => '2 cards you own', 'count' => 2,
                                              'summary' => '±$5.00', 'window' => 'today')
    end

    it 'stays quiet when nothing moved enough' do
      own('Small Riser', price: 101, change: 1)

      expect { evaluate }.not_to change(Notification, :count)
      expect(rule.reload.last_evaluated_on).to eq(Date.parse(today))
    end

    it 'leaves out cards the user watches with their own override in that window' do
      own('Big Riser')
      watched = own('Watched Riser')
      create(:price_alert, :card_override, user: user, magic_card: watched, window: 'daily', min_delta_amount: 50)

      evaluate

      expect(notifications.find_by(notifiable: rule).payload['count']).to eq(1)
    end

    it 'keeps a card whose override watches the other window' do
      own('Big Riser')
      watched = own('Watched Riser')
      create(:price_alert, :card_override, user: user, magic_card: watched, window: 'weekly', min_delta_amount: 50)

      evaluate

      expect(notifications.find_by(notifiable: rule).payload['count']).to eq(2)
    end
  end

  describe 'per-card overrides' do
    let(:card) { create(:magic_card, name: 'The One Ring', normal_price: 110, price_change_daily_normal: 10) }

    def override(**attrs)
      create(:price_alert, :card_override, user: user, magic_card: card, window: 'daily',
                                           finish: 'normal', min_delta_amount: nil, **attrs)
    end

    it 'fires on a unit move that meets the minimums, card nobody owns included' do
      alert = override(min_delta_amount: 5, direction: 'up')

      expect { evaluate }.to change(Notification, :count).by(1)
      expect(notifications.last).to have_attributes(kind: 'price_movement', notifiable: alert)
      expect(notifications.last.payload).to include('subject' => 'The One Ring',
                                                    'summary' => '+$10.00 (+10%)', 'window' => 'today')
    end

    it 'does not fire under the minimum percentage' do
      override(min_delta_percent: 15)

      expect { evaluate }.not_to change(Notification, :count)
    end

    it 'does not fire against its direction' do
      override(min_delta_amount: 5, direction: 'down')

      expect { evaluate }.not_to change(Notification, :count)
    end

    it 'does not fire under the minimum price' do
      override(min_delta_amount: 5, min_price: 200)

      expect { evaluate }.not_to change(Notification, :count)
    end
  end

  describe 'idempotency' do
    it 'never notifies twice for the same price date' do
      card = create(:magic_card, normal_price: 10)
      create(:price_alert, user: user, magic_card: card, threshold_price: 20)
      card.update!(normal_price: 25)

      evaluate

      expect { evaluate }.not_to change(Notification, :count)
    end

    it 'does not re-send a movement rule on a re-run' do
      collection = create(:collection, user: user)
      card = create(:magic_card, normal_price: 110, price_change_daily_normal: 10)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1)
      create(:price_alert, :movement_rule, user: user, window: 'daily', min_delta_amount: 5)

      evaluate

      expect { evaluate }.not_to change(Notification, :count)
    end
  end
end
