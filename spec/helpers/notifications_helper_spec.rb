require 'rails_helper'

RSpec.describe NotificationsHelper, type: :helper do
  let(:trade) { create(:trade) }

  it 'has a sentence for every kind' do
    expect(described_class::TEXT.keys).to match_array(Notification::KINDS)
  end

  it 'names the other party of a trade as the actor' do
    notification = trade.proposer.notifications.create!(kind: 'trade_accepted', notifiable: trade)

    expect(helper.notification_text(notification)).to eq("#{trade.recipient.username} accepted your trade.")
  end

  it 'sends a trade notification to its trade' do
    notification = trade.recipient.notifications.create!(kind: 'trade_proposed', notifiable: trade)

    expect(helper.notification_target_path(notification)).to eq(trade_path(trade))
  end

  describe 'price alerts' do
    let(:user) { create(:user) }
    let(:card) { create(:magic_card, name: 'Sheoldred', normal_price: 10) }
    let(:threshold) { create(:price_alert, user: user, magic_card: card) }
    let(:threshold_payload) do
      { 'card' => 'Sheoldred', 'direction' => 'above', 'threshold' => '$20.00', 'price' => '$25.00' }
    end

    def notify(kind, notifiable, payload)
      user.notifications.create!(kind: kind, notifiable: notifiable, payload: payload)
    end

    it 'words a threshold crossing from its payload' do
      notification = notify('price_threshold_crossed', threshold, threshold_payload)

      expect(helper.notification_text(notification)).to eq('Sheoldred went above $20.00 (now $25.00).')
    end

    it 'words a movement from its payload' do
      notification = notify('price_movement', nil, 'subject' => '7 cards you own', 'count' => 7,
                                                   'summary' => '±$5.00', 'window' => 'today')

      expect(helper.notification_text(notification)).to eq('7 cards you own moved ±$5.00 today.')
    end

    it 'words a band crossing from its payload and sends it to the band worklist' do
      band = create(:price_alert, :band, user: user)
      notification = notify('price_band_crossed', band, 'subject' => '3 cards you own', 'count' => 3,
                                                        'movement' => 'reached $1.00 or more',
                                                        'names' => 'Sol Ring, Arcane Signet and Mind Stone')

      expect(helper.notification_text(notification))
        .to eq('3 cards you own reached $1.00 or more: Sol Ring, Arcane Signet and Mind Stone.')
      expect(helper.notification_target_path(notification)).to eq(price_alert_worklist_path(band))
    end

    it 'still words, and falls back to the notification list, once the alert is deleted' do
      notification = notify('price_threshold_crossed', threshold, threshold_payload)
      threshold.destroy!
      notification.reload

      expect(helper.notification_text(notification)).to eq('Sheoldred went above $20.00 (now $25.00).')
      expect(helper.notification_target_path(notification)).to eq(notifications_path)
    end

    it 'sends a printing threshold to its set in the user collection' do
      notification = notify('price_threshold_crossed', threshold, threshold_payload)

      expect(helper.notification_target_path(notification))
        .to eq(collection_set_path(user.username, card.boxset.code))
    end

    it 'sends an oracle threshold to the want list' do
      alert = create(:price_alert, user: user, magic_card: nil, scryfall_oracle_id: SecureRandom.uuid, finish: 'any')
      notification = notify('price_threshold_crossed', alert, threshold_payload)

      expect(helper.notification_target_path(notification)).to eq(collection_wants_path(user.username))
    end

    it 'sends a movement rule to the movers page with its filters' do
      collection = create(:collection, user: user)
      rule = create(:price_alert, :movement_rule, user: user, collection: collection, direction: 'up',
                                                  min_delta_percent: 15)
      notification = notify('price_movement', rule, {})

      expect(helper.notification_target_path(notification))
        .to eq(collection_movers_path(user.username, collection_id: collection.id, window: 'daily',
                                                     direction: 'up', finish: 'both', min_delta: '5.0',
                                                     min_percent: '15.0'))
    end
  end
end
