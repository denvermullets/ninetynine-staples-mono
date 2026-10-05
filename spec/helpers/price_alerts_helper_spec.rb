require 'rails_helper'

RSpec.describe PriceAlertsHelper, type: :helper do
  let(:user) { create(:user) }
  let(:card) { create(:magic_card) }

  describe '#price_alert_bell_key' do
    it 'keys a printing by id and a card by oracle id' do
      oracle_id = SecureRandom.uuid

      expect(helper.price_alert_bell_key(magic_card_id: 12)).to eq('card-12')
      expect(helper.price_alert_bell_key(scryfall_oracle_id: oracle_id)).to eq("oracle-#{oracle_id}")
    end

    # the key goes into a CSS selector, so nothing but an id or a uuid gets through
    it 'refuses anything that is not an id or a uuid' do
      expect { helper.price_alert_bell_key(magic_card_id: '1"] , *') }.to raise_error(ArgumentError)
      expect { helper.price_alert_bell_key(scryfall_oracle_id: 'x"], [data-x="') }.to raise_error(ArgumentError)
    end
  end

  describe '#price_alert_bell_id' do
    it 'names a bell by its placement and card' do
      expect(helper.price_alert_bell_id('wants_table', 'card-12')).to eq('price_alert_bell_wants_table_card-12')
    end

    it 'refuses a placement that no write would relight' do
      expect { helper.price_alert_bell_id('sidebar', 'card-12') }.to raise_error(ArgumentError)
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
