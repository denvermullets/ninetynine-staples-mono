require 'rails_helper'

RSpec.describe CollectionStats::Sets, type: :service do
  subject(:result) { described_class.call(collection_ids: [collection.id]) }

  let(:collection) { create(:collection) }

  def add(boxset, quantity: 1, price: 10)
    card = create(:magic_card, boxset: boxset, normal_price: price)
    create(:collection_magic_card, collection: collection, magic_card: card, quantity: quantity)
    card
  end

  def boxset(name, release_date: '2024-01-01', keyrune_code: 'PMTG1')
    create(:boxset, name: name, release_date: release_date, keyrune_code: keyrune_code)
  end

  def ranked(label)
    result[:top_sets].find { |row| row[:label] == label }
  end

  def year_row(label)
    result[:years].find { |row| row[:label] == label }
  end

  def track_queries
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
    end
    yield
    ActiveSupport::Notifications.unsubscribe(subscriber)
    queries
  end

  describe 'the single scan' do
    # the entire justification for GROUPING SETS - split this into two queries and this fails
    it 'answers both questions in one query' do
      add(boxset('Alpha'))

      queries = track_queries { result }

      expect(queries.size).to eq(1)
      expect(result[:top_sets]).not_to be_empty
      expect(result[:years]).not_to be_empty
    end

    it 'splits two sets from the same year into two set rows and one year row' do
      add(boxset('Alpha', release_date: '2024-03-01'), quantity: 2)
      add(boxset('Beta', release_date: '2024-09-01'), quantity: 3)

      expect(result[:top_sets].map { |row| row[:label] }).to contain_exactly('Alpha', 'Beta')
      expect(result[:years].map { |row| row[:label] }).to eq(['2024'])
      expect(year_row('2024')[:copies]).to eq(5)
    end
  end

  describe 'top sets' do
    it 'ranks by value rather than by copies' do
      add(boxset('Pricey'), quantity: 1, price: 300)
      add(boxset('Bulky'), quantity: 10, price: 10)

      expect(result[:top_sets].map { |row| row[:label] }).to eq(%w[Pricey Bulky])
    end

    it 'folds everything past the top ten into one row' do
      12.times { |n| add(boxset(format('Set %02d', n)), price: 100 - n) }

      labels = result[:top_sets].map { |row| row[:label] }

      expect(labels.size).to eq(described_class::TOP + 1)
      expect(labels.last).to eq('Other sets (2)')
      expect(result[:top_sets].sum { |row| row[:share] }).to eq(100.0)
    end

    it 'leaves the folded row without a set icon' do
      11.times { |n| add(boxset(format('Set %02d', n)), price: 100 - n) }

      expect(result[:top_sets].last[:icon]).to be_nil
    end

    it 'counts every set represented, not just the ones it lists' do
      12.times { |n| add(boxset(format('Set %02d', n))) }

      expect(result[:set_count]).to eq(12)
    end

    it 'builds a lowercased keyrune icon with no rarity gradient' do
      add(boxset('Alpha', keyrune_code: 'LEA'))

      expect(ranked('Alpha')[:icon]).to eq('no-tailwind ss ss-lea ss-fw')
    end

    it 'skips the icon when the set has no keyrune code' do
      add(boxset('Alpha', keyrune_code: nil))

      expect(ranked('Alpha')[:icon]).to be_nil
    end

    it 'carries the release year for free' do
      add(boxset('Alpha', release_date: '2019-07-12'))

      expect(ranked('Alpha')[:year]).to eq(2019)
    end
  end

  describe 'the year timeline' do
    it 'fills the gap years so the run is not compressed' do
      add(boxset('Old', release_date: '2018-05-01'))
      add(boxset('New', release_date: '2021-05-01'))

      expect(result[:years].map { |row| row[:label] }).to eq(%w[2018 2019 2020 2021])
      expect(year_row('2019')[:copies]).to be_zero
    end

    # dropping these would quietly stop the year totals reconciling with the set totals
    it 'keeps a set with no release date, under Unknown, at the end' do
      add(boxset('Dated', release_date: '2020-01-01'))
      add(boxset('Undated', release_date: nil), quantity: 4)

      expect(result[:years].last[:label]).to eq('Unknown')
      expect(year_row('Unknown')[:copies]).to eq(4)
      expect(ranked('Undated')).to be_present
    end
  end

  describe 'figures' do
    # copies count all four finishes; value counts the two real ones - 1 + 2, not 1 + 2 + 1 + 2
    it 'counts every finish but values real copies only' do
      card = create(:magic_card, boxset: boxset('Alpha'), normal_price: 1, foil_price: 2)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 1, foil_quantity: 1,
                                     proxy_quantity: 1, proxy_foil_quantity: 1)

      expect(ranked('Alpha')[:copies]).to eq(4)
      expect(ranked('Alpha')[:value]).to eq(3)
    end

    it 'excludes staged and wishlist rows' do
      card = create(:magic_card, boxset: boxset('Alpha'), normal_price: 5)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 4, staged: true)

      expect(result[:top_sets]).to be_empty
      expect(result[:years]).to be_empty
    end
  end

  it 'returns nothing and runs no queries when there are no collections' do
    queries = track_queries { described_class.call(collection_ids: []) }

    expect(described_class.call(collection_ids: []))
      .to eq({ top_sets: [], years: [], set_count: 0 })
    expect(queries).to be_empty
  end
end
