require 'rails_helper'

RSpec.describe PriceAlerts::Save do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:card) { create(:magic_card, normal_price: 12, foil_price: 30) }

  def params(**attributes)
    ActionController::Parameters.new(attributes)
  end

  def threshold(**overrides)
    params(kind: 'threshold', magic_card_id: card.id, finish: 'foil', direction: 'above', threshold_price: '40',
           **overrides)
  end

  describe 'creating' do
    it 'creates a threshold alert for the user, sided against the current price' do
      result = described_class.call(user: user, params: threshold)

      expect(result[:success]).to be(true)
      expect(result[:alert]).to have_attributes(user: user, kind: 'threshold', magic_card_id: card.id, finish: 'foil',
                                                direction: 'above', threshold_price: 40, last_side: 'below')
    end

    it 'drops fields a threshold alert does not take' do
      alert = described_class.call(user: user, params: threshold(window: 'daily', min_delta_amount: '5',
                                                                 active: 'false', user_id: other_user.id,
                                                                 last_fired_at: 1.day.ago))[:alert]

      expect(alert.reload).to have_attributes(user: user, window: nil, min_delta_amount: nil, active: true,
                                              last_fired_at: nil)
    end

    it 'creates a per-card movement override' do
      result = described_class.call(user: user, params: params(kind: 'movement', magic_card_id: card.id,
                                                               finish: 'any', direction: 'both', window: 'weekly',
                                                               min_delta_amount: '5'))

      expect(user.price_alerts.card_overrides.sole).to eq(result[:alert])
    end

    it 'never lets a movement alert watch an oracle id' do
      result = described_class.call(user: user, params: params(kind: 'movement', scryfall_oracle_id: SecureRandom.uuid,
                                                               direction: 'both', window: 'daily',
                                                               min_delta_amount: '5'))

      expect(result[:alert].scryfall_oracle_id).to be_nil
      expect(result[:alert]).to be_movement_rule
    end

    it "refuses a movement rule on someone else's collection" do
      collection = create(:collection, user: other_user)

      result = described_class.call(user: user, params: params(kind: 'movement', collection_id: collection.id,
                                                               direction: 'both', window: 'daily',
                                                               min_delta_amount: '5'))

      expect(result[:success]).to be(false)
      expect(result[:alert].errors[:collection]).to include('must be one of your collections')
      expect(PriceAlert.count).to eq(0)
    end

    it 'refuses an unknown kind' do
      result = described_class.call(user: user, params: threshold(kind: 'bogus'))

      expect(result[:success]).to be(false)
      expect(PriceAlert.count).to eq(0)
    end
  end

  describe 'updating' do
    let(:alert) { create(:price_alert, user: user, magic_card: card, threshold_price: 20) }

    it 'changes the condition and re-sides it' do
      described_class.call(user: user, alert: alert, params: params(threshold_price: '8', direction: 'below'))

      expect(alert.reload).to have_attributes(threshold_price: 8, direction: 'below', last_side: 'above')
    end

    it 'pauses an alert' do
      described_class.call(user: user, alert: alert, params: params(active: 'false'))

      expect(alert.reload).not_to be_active
    end

    it 'never moves an alert to another card' do
      described_class.call(user: user, alert: alert,
                           params: params(magic_card_id: create(:magic_card).id, scryfall_oracle_id: SecureRandom.uuid))

      expect(alert.reload).to have_attributes(magic_card_id: card.id, scryfall_oracle_id: nil)
    end

    it 'never changes the kind' do
      described_class.call(user: user, alert: alert, params: params(kind: 'movement', window: 'daily'))

      expect(alert.reload).to have_attributes(kind: 'threshold', window: nil)
    end
  end
end
