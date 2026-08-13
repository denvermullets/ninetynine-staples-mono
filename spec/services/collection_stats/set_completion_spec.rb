require 'rails_helper'

RSpec.describe CollectionStats::SetCompletion, type: :service do
  subject(:result) { described_class.call(collection_ids: [collection.id]) }

  let(:collection) { create(:collection) }

  # the factory leaves card_number nil, and the base run is read off it, so every card here says
  # where in the set it sits
  def card(boxset, number, **attributes)
    create(:magic_card, boxset: boxset, card_number: number.to_s, **attributes)
  end

  def own(card, **attributes)
    create(:collection_magic_card, { collection: collection, magic_card: card,
                                     quantity: 1 }.merge(attributes))
  end

  def boxset(name, base: 3, **attributes)
    create(:boxset, { name: name, base_set_size: base, total_set_size: base }.merge(attributes))
  end

  def row(label)
    result[:sets].find { |set| set[:label] == label }
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
    # the denominator is the cards the app has for the set, not boxsets.total_set_size - the two
    # agree on real data, and counting rows is what lets a finished set land on exactly 100%
    it 'counts the set and the part of it owned in one query' do
      set = boxset('Alpha')
      own(card(set, 1))
      card(set, 2)
      card(set, 3)

      queries = track_queries { result }

      expect(queries.size).to eq(1)
      expect(row('Alpha')).to include(owned: 1, total: 3)
    end
  end

  describe 'what completion means' do
    it 'measures owned printings against the whole numbered run' do
      set = boxset('Alpha')
      own(card(set, 1))
      own(card(set, 2))
      card(set, 3)

      expect(row('Alpha')).to include(owned: 2, total: 3, missing: 1, share: 66.7, basis: :base)
    end

    it 'counts a printing once however many copies of it are on the shelf' do
      set = boxset('Alpha')
      own(card(set, 1), quantity: 4, foil_quantity: 2, proxy_quantity: 3)
      card(set, 2)
      card(set, 3)

      expect(row('Alpha')).to include(owned: 1, total: 3)
    end

    it 'reaches exactly 100% when the run is finished' do
      set = boxset('Alpha')
      3.times { |n| own(card(set, n + 1)) }

      expect(row('Alpha')).to include(share: 100.0, missing: 0)
      expect(result[:complete]).to eq(1)
    end

    it 'leaves out a set nothing is owned from' do
      own(card(boxset('Alpha'), 1))
      card(boxset('Beta'), 1)

      expect(result[:sets].map { |set| set[:label] }).to eq(['Alpha'])
      expect(result[:touched]).to eq(1)
    end
  end

  describe 'variants' do
    # the showcase printing is not part of the run, so it must not move the bar - but somebody who
    # collects them still wants to see it
    it 'keeps printings past the run out of the headline and reports them underneath' do
      set = boxset('Alpha', base: 2, total_set_size: 4)
      own(card(set, 1))
      card(set, 2)
      own(card(set, 3))
      card(set, 4)

      expect(row('Alpha')).to include(owned: 1, total: 2, share: 50.0,
                                      variant_owned: 2, variant_total: 4)
    end

    it 'measures a set with no meaningful run across every printing instead' do
      set = boxset('Secret Lair', base: 1, total_set_size: 4)
      own(card(set, 1))
      own(card(set, 2))
      card(set, 3)
      card(set, 4)

      expect(row('Secret Lair')).to include(basis: :all, owned: 2, total: 4, share: 50.0)
    end

    it 'reads a suffixed collector number as its number' do
      set = boxset('Alpha', base: 2, total_set_size: 3)
      own(card(set, '1a'))
      card(set, 2)
      card(set, 3)

      expect(row('Alpha')).to include(owned: 1, total: 2)
    end
  end

  describe 'what is not a card you can collect' do
    it 'ignores tokens and the back face of a double-faced card' do
      set = boxset('Alpha')
      own(card(set, 1))
      card(set, 2)
      card(set, 3)
      own(card(set, 4, is_token: true))
      own(card(set, 5, card_side: 'b'))

      expect(row('Alpha')).to include(owned: 1, total: 3, variant_total: 3)
    end

    # the point of the panel is what is left to buy, and a proxy is what you print because you have
    # not bought it
    it 'does not count a printing owned only as a proxy' do
      set = boxset('Alpha')
      own(card(set, 1))
      own(card(set, 2), quantity: 0, proxy_quantity: 4)
      own(card(set, 3), quantity: 0, proxy_foil_quantity: 1)

      expect(row('Alpha')).to include(owned: 1, total: 3, missing: 2, variant_owned: 1)
    end

    it 'leaves out a set held entirely in proxies' do
      own(card(boxset('Alpha'), 1))
      own(card(boxset('Proxied'), 1), quantity: 0, proxy_quantity: 2)

      expect(result[:sets].map { |set| set[:label] }).to eq(['Alpha'])
      expect(result[:touched]).to eq(1)
    end

    it 'ignores staged and wishlist rows, same as the rest of the dashboard' do
      set = boxset('Alpha')
      own(card(set, 1), staged: true)
      own(card(set, 2), needed: true)

      expect(result[:sets]).to be_empty
    end
  end

  describe 'the ranking' do
    it 'puts the larger set first when two are equally complete' do
      big = boxset('Big', base: 3)
      3.times { |n| own(card(big, n + 1)) }
      own(card(boxset('Tiny', base: 1), 1))

      expect(result[:sets].map { |set| set[:label] }).to eq(%w[Big Tiny])
    end

    it 'ranks by how complete a set is, not by how much of it is owned' do
      close = boxset('Close', base: 2)
      own(card(close, 1))
      card(close, 2)
      broad = boxset('Broad', base: 10)
      10.times { |n| n < 3 ? own(card(broad, n + 1)) : card(broad, n + 1) }

      expect(result[:sets].map { |set| set[:label] }).to eq(%w[Close Broad])
      expect(result[:half]).to eq(1)
    end
  end

  describe 'the row itself' do
    it 'carries the icon, code and year the panel links and labels with' do
      set = boxset('Alpha', code: 'LEA', keyrune_code: 'LEA', release_date: '1993-08-05')
      own(card(set, 1))

      expect(row('Alpha')).to include(code: 'LEA', icon: 'no-tailwind ss ss-lea ss-fw', year: 1993)
    end

    it 'leaves the year blank for a set with no release date' do
      own(card(boxset('Undated', release_date: nil), 1))

      expect(row('Undated')[:year]).to be_nil
    end
  end

  it 'returns nothing and runs no queries when there are no collections' do
    queries = track_queries { described_class.call(collection_ids: []) }

    expect(described_class.call(collection_ids: []))
      .to eq({ sets: [], complete: 0, half: 0, touched: 0 })
    expect(queries).to be_empty
  end
end
