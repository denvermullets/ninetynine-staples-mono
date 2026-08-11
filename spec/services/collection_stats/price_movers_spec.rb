require 'rails_helper'

RSpec.describe CollectionStats::PriceMovers, type: :service do
  subject(:result) { described_class.call(collection_ids: [collection.id]) }

  let(:collection) { create(:collection) }

  # price_change_weekly_normal is a percentage, so the dollar move is derived: a $110 card that
  # rose 10% was $100 a week ago and gained $10
  def add(name, price: 100, change: 10, quantity: 1, **card_attrs)
    card = create(:magic_card, name: name, normal_price: price,
                               price_change_weekly_normal: change, **card_attrs)
    create(:collection_magic_card, collection: collection, magic_card: card, quantity: quantity)
    card
  end

  def row(name)
    result.find { |mover| mover[:name] == name }
  end

  describe 'the dollar move' do
    it 'recovers the move from the percentage and the current price' do
      add('Riser', price: 110, change: 10)

      expect(row('Riser')[:delta]).to eq(10)
    end

    it 'multiplies the move by the copies you hold' do
      add('Riser', price: 110, change: 10, quantity: 4)

      expect(row('Riser')[:delta]).to eq(40)
    end

    it 'reports a fall as a negative move' do
      add('Faller', price: 90, change: -10)

      expect(row('Faller')[:delta]).to eq(-10)
    end

    it 'adds the foil move to the non-foil move on the same card' do
      card = create(:magic_card, name: 'Both Finishes', normal_price: 110,
                                 price_change_weekly_normal: 10, foil_price: 220,
                                 price_change_weekly_foil: 10)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1,
                                     foil_quantity: 1)

      expect(row('Both Finishes')[:delta]).to eq(30)
    end
  end

  describe 'ranking' do
    it 'ranks gainers and losers together on the size of the move' do
      add('Small Gain', price: 110, change: 10)
      add('Big Loss', price: 50, change: -50)
      add('Medium Gain', price: 120, change: 20)

      expect(result.map { |mover| mover[:name] }).to eq(['Big Loss', 'Medium Gain', 'Small Gain'])
    end

    it 'keeps the list to the top ten' do
      12.times { |n| add("Card #{n}", price: 100 + n, change: n + 1) }

      expect(result.size).to eq(described_class::TOP)
    end
  end

  describe 'what is left out' do
    it 'drops cards whose move rounds to nothing' do
      add('Bulk Common', price: 0.01, change: 5)
      add('Real Mover', price: 110, change: 10)

      expect(result.map { |mover| mover[:name] }).to eq(['Real Mover'])
    end

    it 'drops cards with no recorded weekly change' do
      add('Unmoved', change: nil)

      expect(result).to be_empty
    end

    # a price that fell to zero cannot have its old price recovered from -100%
    it 'drops a card that lost all of its value' do
      add('Wiped Out', price: 0, change: -100)

      expect(result).to be_empty
    end

    it 'ignores proxy copies - a proxy price did not move' do
      card = create(:magic_card, name: 'Proxied', normal_price: 110,
                                 price_change_weekly_normal: 10)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1,
                                     proxy_quantity: 20)

      expect(row('Proxied')).to include(delta: 10, copies: 1)
    end

    it 'leaves a proxy-only holding out of the list entirely' do
      card = create(:magic_card, name: 'Proxy Only', normal_price: 110,
                                 price_change_weekly_normal: 10)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 0,
                                     proxy_quantity: 4)

      expect(result).to be_empty
    end

    it 'ignores staged and needed rows the way every other panel does' do
      card = create(:magic_card, name: 'Deck Scratch', normal_price: 110,
                                 price_change_weekly_normal: 10)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1,
                                     needed: true)

      expect(result).to be_empty
    end
  end

  describe 'presentation' do
    it 'colours a gainer and a loser differently' do
      add('Riser', price: 110, change: 10)
      add('Faller', price: 90, change: -10)

      expect(row('Riser')[:delta_class]).to eq(described_class::GAIN_CLASS)
      expect(row('Faller')[:delta_class]).to eq(described_class::LOSS_CLASS)
    end

    it 'states the move as a percentage of what the copies were worth a week ago' do
      add('Riser', price: 110, change: 10, quantity: 3)

      expect(row('Riser')[:percent]).to eq(10.0)
    end

    it 'carries the art and set glyph the list renders' do
      boxset = create(:boxset, name: 'Alpha', keyrune_code: 'LEA')
      add('Black Lotus', boxset: boxset, image_small: 'small.jpg', image_large: 'large.jpg')

      expect(row('Black Lotus')).to include(
        set_name: 'Alpha', icon: 'no-tailwind ss ss-lea ss-fw',
        image: 'small.jpg', image_large: 'large.jpg'
      )
    end

    it 'reports the value of the real copies alongside the move' do
      add('Riser', price: 110, change: 10, quantity: 2)

      expect(row('Riser')).to include(value: 220, copies: 2)
    end
  end

  describe 'an empty scope' do
    it 'returns an empty list without touching the database' do
      queries = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
      end

      expect(described_class.call(collection_ids: [])).to eq([])
      expect(queries).to be_empty
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end
end
