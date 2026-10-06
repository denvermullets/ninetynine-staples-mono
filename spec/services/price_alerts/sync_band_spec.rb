require 'rails_helper'

RSpec.describe PriceAlerts::SyncBand do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user, name: 'Binder') }
  let(:band) { create(:price_alert, :band, user: user) }
  let(:today) { Date.new(2026, 10, 6) }

  # held: the collection_magic_card's collection and quantities
  def own(name, price: 0.5, foil_price: 0, held: {}, **card_attrs)
    card = create(:magic_card, name: name, normal_price: price, foil_price: foil_price, **card_attrs)
    create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1, **held)
    card
  end

  def sync(on: today, audit: false)
    described_class.call(band: band.reload, on: on, audit: audit)
  end

  def state(card, finish: 'normal')
    band.band_cards.find_by(magic_card: card, finish: finish)
  end

  describe 'learning a card the band has not seen' do
    it 'arms a card under the threshold, the in-between ones included' do
      cheap = own('Cheap', price: 0.5)
      between = own('Between', price: 0.95)

      expect(sync).to be_empty
      expect(state(cheap)).to have_attributes(state: 'armed', handled_at: nil)
      expect(state(between)).to have_attributes(state: 'armed')
    end

    it 'takes a card already past the line as where it belongs by default, listing nothing' do
      card = own('Already Pricey', price: 3)

      expect(sync).to be_empty
      expect(state(card)).to have_attributes(state: 'crossed', crossed_on: nil, moved: nil, handled_at: nil)
      expect(band.band_cards.listed).to be_empty
    end

    it 'lists a card already past the line when auditing, without reporting it as a new crossing' do
      card = own('Already Pricey', price: 3)

      expect(sync(audit: true)).to be_empty
      expect(band.band_cards.to_do.sole).to have_attributes(magic_card: card, moved: 'up', crossed_price: 3)
    end

    it 'leaves an audited card off the list when it is outside the buylist range' do
      band.update!(min_buylist_price: 0.25)
      own('No Buylist', price: 3, ck_buylist_normal_price: 0)
      listed = own('Buylisted', price: 3, ck_buylist_normal_price: 1)

      sync(audit: true)

      expect(band.band_cards.to_do.map(&:magic_card)).to eq([listed])
    end

    it 'skips a card with no price, rather than calling it under the line' do
      own('Unpriced', price: 0)

      sync

      expect(band.band_cards).to be_empty
    end
  end

  describe 'a card it already knows' do
    let!(:card) { own('Penny Card', price: 0.85) }

    before { sync }

    it 'lists a card that reaches the threshold and says so' do
      card.update!(normal_price: 1.02)

      expect(sync(on: today + 1).map { |holding| holding.values_at(:magic_card_id, :moved) }).to eq([[card.id, 'up']])
      expect(state(card)).to have_attributes(state: 'crossed', crossed_on: today + 1, crossed_price: 1.02,
                                             moved: 'up', handled_at: nil)
    end

    it 'counts landing exactly on the threshold as reaching it' do
      card.update!(normal_price: 1)

      expect(sync(on: today + 1)).to be_present
    end

    it 'catches a slow climb over several days' do
      card.update!(normal_price: 0.95)
      expect(sync(on: today + 1)).to be_empty

      card.update!(normal_price: 1.01)
      expect(sync(on: today + 2)).to be_present
    end

    it 'moves the side of a card outside the buylist range without listing it' do
      band.update!(min_buylist_price: 0.25)
      card.update!(normal_price: 1.5, ck_buylist_normal_price: 0.1)

      expect(sync(on: today + 1)).to be_empty
      expect(state(card)).to have_attributes(state: 'crossed', crossed_on: nil)
    end

    it 'takes a crossing that is undone before it was handled back off the list' do
      card.update!(normal_price: 1.2)
      sync(on: today + 1)
      card.update!(normal_price: 0.8)

      expect(sync(on: today + 2)).to be_empty
      expect(state(card)).to have_attributes(state: 'armed', crossed_on: nil)
    end

    context 'once crossed' do
      before do
        card.update!(normal_price: 1.2)
        sync(on: today + 1)
        state(card).update!(handled_at: Time.current)
      end

      it 'stays put between the lines' do
        card.update!(normal_price: 0.95)

        expect(sync(on: today + 2)).to be_empty
        expect(state(card)).to have_attributes(state: 'crossed')
        expect(state(card).handled_at).to be_present
      end

      it 're-arms at the from price quietly, and lists the next crossing afresh' do
        card.update!(normal_price: 0.9)
        expect(sync(on: today + 2)).to be_empty
        expect(state(card)).to have_attributes(state: 'armed', handled_at: nil, crossed_on: nil)

        card.update!(normal_price: 1.1)
        expect(sync(on: today + 3)).to be_present
        expect(state(card)).to have_attributes(state: 'crossed', handled_at: nil, crossed_on: today + 3)
      end
    end

    it 'deletes the row for a card no longer held, so a card coming back is learned afresh' do
      CollectionMagicCard.where(magic_card: card).delete_all

      sync(on: today + 1)

      expect(band.band_cards).to be_empty
    end

    it 'keeps the row for a held card that has lost its price' do
      card.update!(normal_price: 0)

      sync(on: today + 1)

      expect(state(card)).to have_attributes(state: 'armed')
    end
  end

  describe 'a two-way band' do
    let(:band) { create(:price_alert, :band, user: user, direction: 'both') }

    it 'lists a card bought high that the market drops back to the from price' do
      card = own('Fresh Set Rare', price: 2)
      sync
      card.update!(normal_price: 1.4)
      expect(sync(on: today + 1)).to be_empty

      card.update!(normal_price: 0.5)
      expect(sync(on: today + 2).map { |holding| holding[:moved] }).to eq(['down'])
      expect(state(card)).to have_attributes(state: 'armed', moved: 'down', crossed_on: today + 2,
                                             crossed_price: 0.5, handled_at: nil)
    end

    it 'lists the climb, then once that is handled, the drop' do
      card = own('Riser', price: 0.5)
      sync
      card.update!(normal_price: 1.1)
      expect(sync(on: today + 1).map { |holding| holding[:moved] }).to eq(['up'])

      state(card).update!(handled_at: Time.current)
      card.update!(normal_price: 0.85)
      expect(sync(on: today + 2).map { |holding| holding[:moved] }).to eq(['down'])
      expect(state(card).handled_at).to be_nil
    end

    it 'takes a climb back off the list when the card drops again before it was handled' do
      card = own('Spike', price: 0.5)
      sync
      card.update!(normal_price: 1.1)
      sync(on: today + 1)
      card.update!(normal_price: 0.6)

      expect(sync(on: today + 2)).to be_empty
      expect(band.band_cards.to_do).to be_empty
    end
  end

  describe 'a below band' do
    let(:band) { create(:price_alert, :band, user: user, direction: 'below', threshold_price: 1, from_price: 1.1) }

    it 'arms over the threshold, lists a drop under it and re-arms at the from price' do
      card = own('Faller', price: 1.5)
      sync
      expect(state(card)).to have_attributes(state: 'armed')

      card.update!(normal_price: 0.95)
      expect(sync(on: today + 1).map { |holding| holding[:moved] }).to eq(['down'])

      card.update!(normal_price: 1.1)
      expect(sync(on: today + 2)).to be_empty
      expect(state(card)).to have_attributes(state: 'armed')
    end
  end

  describe 'what the band watches' do
    it 'places each finish held on its own price' do
      card = own('Both', price: 0.5, foil_price: 4, held: { foil_quantity: 1 })

      sync

      expect(state(card, finish: 'normal')).to have_attributes(state: 'armed')
      expect(state(card, finish: 'foil')).to have_attributes(state: 'crossed')
    end

    it 'leaves out a finish held only as a proxy' do
      card = create(:magic_card, normal_price: 5)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 0, proxy_quantity: 2)

      sync

      expect(band.band_cards).to be_empty
    end

    it 'narrows to its finish' do
      band.update!(finish: 'foil')
      own('Both', price: 0.5, foil_price: 4, held: { foil_quantity: 1 })

      sync

      expect(band.band_cards.pluck(:finish)).to eq(['foil'])
    end

    it 'narrows to its collection' do
      other = create(:collection, user: user, name: 'Other')
      band.update!(collection: collection)
      inside = own('Inside')
      own('Outside', held: { collection: other })

      sync

      expect(band.band_cards.map(&:magic_card)).to eq([inside])
    end

    it "never counts someone else's cards" do
      own('Theirs', held: { collection: create(:collection) })

      sync

      expect(band.band_cards).to be_empty
    end
  end
end
