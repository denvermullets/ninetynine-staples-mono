require 'rails_helper'

RSpec.describe CollectionStats::ManaCurve, type: :service do
  subject(:result) { described_class.call(collection_ids: [collection.id]) }

  let(:collection) { create(:collection) }

  def add(mana_value, quantity: 1, types: [], **attrs)
    card = create(:magic_card, { mana_value: mana_value, normal_price: 10 }.merge(attrs))
    types.each do |name|
      MagicCardType.create!(magic_card: card, card_type: CardType.find_or_create_by!(name: name))
    end
    create(:collection_magic_card, collection: collection, magic_card: card, quantity: quantity)
    card
  end

  def bucket(label)
    result[:buckets].find { |row| row[:label] == label }
  end

  def copies
    result[:buckets].sum { |row| row[:copies] }
  end

  describe 'exclusions' do
    it 'leaves lands out of the curve entirely' do
      add(0, types: %w[Land])

      expect(copies).to eq(0)
    end

    # the fan-out guard: a LEFT JOIN onto magic_card_types would give this card two rows and
    # bill four copies to the 3 bucket instead of two
    it 'counts a multi-type card once' do
      add(3, quantity: 2, types: %w[Artifact Creature])

      expect(bucket('3')[:copies]).to eq(2)
      expect(copies).to eq(2)
    end

    it 'leaves tokens out too' do
      add(0, is_token: true)

      expect(copies).to eq(0)
    end

    it 'excludes staged and wishlist rows' do
      card = create(:magic_card, mana_value: 2)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 4, needed: true)

      expect(copies).to eq(0)
    end
  end

  describe 'bucketing' do
    it 'gives every mana value below the cap its own bucket' do
      (0..6).each { |mana_value| add(mana_value) }

      expect(result[:buckets].first(7).map { |row| row[:copies] }).to all(eq(1))
    end

    it 'folds everything at or above the cap into one bucket' do
      [7, 9, 12].each { |mana_value| add(mana_value) }

      expect(bucket('7+')[:copies]).to eq(3)
    end

    it 'files a card with no recorded mana value under X' do
      add(nil)

      expect(bucket('X')[:copies]).to eq(1)
    end

    # X means "no mana value", not "costs {X}" - Fireball is a one-drop and stays one
    it 'leaves an X-cost spell in the bucket its pips put it in' do
      add(1, mana_cost: '{X}{R}')

      expect(bucket('1')[:copies]).to eq(1)
      expect(bucket('X')[:copies]).to eq(0)
    end

    # FLOOR, not a cast - Postgres would round 0.5 up to 1
    it 'floors a half-mana card rather than rounding it up' do
      add(0.5)

      expect(bucket('0')[:copies]).to eq(1)
      expect(bucket('1')[:copies]).to eq(0)
    end

    it 'keeps empty buckets so the curve does not close its own gaps' do
      add(2)
      add(5)

      expect(result[:buckets].map { |row| row[:label] }).to eq(described_class::BUCKETS)
      expect(bucket('3')[:copies]).to be_zero
    end

    it 'runs 0 through the cap and finishes on X' do
      expect(described_class::BUCKETS).to eq(%w[0 1 2 3 4 5 6 7+ X])
    end
  end

  describe 'figures' do
    it 'sums copies and value per bucket' do
      add(2, quantity: 3, normal_price: 10)
      add(2, quantity: 2, normal_price: 5)

      expect(bucket('2')[:copies]).to eq(5)
      expect(bucket('2')[:value]).to eq(40)
    end

    it 'counts every finish, not just non-foil copies' do
      card = create(:magic_card, mana_value: 4, normal_price: 1, foil_price: 2)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 1, foil_quantity: 1,
                                     proxy_quantity: 1, proxy_foil_quantity: 1)

      expect(bucket('4')[:copies]).to eq(4)
      expect(bucket('4')[:value]).to eq(6)
    end

    it 'averages mana value across copies, not across printings' do
      add(1, quantity: 3)
      add(5, quantity: 1)

      expect(result[:average]).to eq(2.0)
    end

    it 'leaves cards with no mana value out of the average' do
      add(2, quantity: 1)
      add(nil, quantity: 9)

      expect(result[:average]).to eq(2.0)
    end

    it 'reports a zero average when every card is a land' do
      add(3, types: %w[Land])

      expect(result[:average]).to eq(0.0)
    end
  end

  it 'returns a zeroed curve and runs no queries when there are no collections' do
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
    end
    empty = described_class.call(collection_ids: [])
    ActiveSupport::Notifications.unsubscribe(subscriber)

    expect(empty[:buckets].map { |row| row[:label] }).to eq(described_class::BUCKETS)
    expect(empty[:buckets].map { |row| row[:copies] }).to all(be_zero)
    expect(empty[:average]).to eq(0.0)
    expect(queries).to be_empty
  end
end
