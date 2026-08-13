require 'rails_helper'

RSpec.describe CollectionStats::SetCards, type: :service do
  subject(:rows) { call[:rows] }

  let(:collection) { create(:collection) }
  let(:set) { create(:boxset, name: 'Alpha', base_set_size: 2, total_set_size: 4) }
  let(:filter) { 'all' }

  def call(mode = filter)
    described_class.call(collection_ids: [collection.id], boxset: set, filter: mode)
  end

  # the factory names every card Black Lotus and leaves scryfall_oracle_id nil, so a spec that does
  # not say otherwise is asking for the name fallback - each card here is explicit about which
  # printing of which card it is
  def card(number, name: nil, oracle: SecureRandom.uuid, **attributes)
    create(:magic_card, boxset: set, card_number: number.to_s, scryfall_oracle_id: oracle,
                        name: name || "Card #{number}", **attributes)
  end

  def own(magic_card, **attributes)
    create(:collection_magic_card, { collection: collection, magic_card: magic_card,
                                     quantity: 1 }.merge(attributes))
  end

  def row(name)
    rows.find { |group| group[:name] == name }
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

  describe 'folding printings into cards' do
    it 'puts every printing of a card under one row' do
      oracle = SecureRandom.uuid
      own(card(1, name: 'Agate Assault', oracle: oracle))
      card(3, name: 'Agate Assault', oracle: oracle)
      card(4, name: 'Agate Assault', oracle: oracle)

      expect(rows.size).to eq(1)
      expect(row('Agate Assault')).to include(owned_printings: 1, total_printings: 3, owned: true)
    end

    # the base printing is the card as the set numbers it, so it names and prices the row
    it 'names the row after the printing in the numbered run' do
      oracle = SecureRandom.uuid
      card(3, name: 'Agate Assault', oracle: oracle, normal_price: 40)
      card(1, name: 'Agate Assault', oracle: oracle, normal_price: 2)

      expect(row('Agate Assault')[:primary]).to include(number: '1', normal_price: 2, in_base: true)
    end

    it 'falls back to the first printing when none of them is in the run' do
      set.update!(base_set_size: 0)
      oracle = SecureRandom.uuid
      card(4, name: 'Agate Assault', oracle: oracle)
      card(3, name: 'Agate Assault', oracle: oracle)

      expect(row('Agate Assault')[:primary]).to include(number: '3')
    end

    # an unbackfilled oracle id is a null, and every null is not the same card
    it 'falls back to the name when a printing has no oracle id' do
      own(card(1, name: 'Agate Assault', oracle: nil))
      card(3, name: 'Agate Assault', oracle: nil)
      card(2, name: 'Bakersbane Duo', oracle: nil)

      expect(rows.size).to eq(2)
      expect(row('Agate Assault')).to include(total_printings: 2)
    end

    # the columns are plucked and destructured positionally, so the strip of variant thumbnails goes
    # blank the moment somebody adds a column in the middle of the list without moving this
    it 'carries the art, so the printings strip can show the variants rather than describe them' do
      card(1, name: 'Agate Assault', image_medium: 'https://example.test/agate.jpg',
              image_large: 'https://example.test/agate-large.jpg')

      expect(row('Agate Assault')[:primary]).to include(image: 'https://example.test/agate.jpg',
                                                        image_large: 'https://example.test/agate-large.jpg',
                                                        rarity: 'rare', number: '1')
    end

    # the hover preview is the only way to actually read a card off a thumbnail, so a printing with
    # no large scan has to fall back rather than hand the preview an empty src
    it 'falls back to the thumbnail when a printing has no large scan' do
      card(1, name: 'Agate Assault', image_medium: 'https://example.test/agate.jpg', image_large: nil)

      expect(row('Agate Assault')[:primary][:image_large]).to eq('https://example.test/agate.jpg')
    end

    it 'reads the set in collector number order' do
      card(2)
      card(10)
      card(1)

      expect(rows.map { |group| group[:primary][:number] }).to eq(%w[1 2 10])
    end
  end

  describe 'owned and missing' do
    before do
      own(card(1, name: 'Have'))
      card(2, name: 'Want')
    end

    it 'counts a card as owned when any of its printings is' do
      expect(call('owned')[:rows].map { |group| group[:name] }).to eq(['Have'])
    end

    it 'counts a card as missing only when none of its printings is' do
      expect(call('missing')[:rows].map { |group| group[:name] }).to eq(['Want'])
    end

    it 'labels all three toggles off the same pass' do
      expect(call('missing')[:counts]).to eq({ all: 2, owned: 1, missing: 1 })
    end

    it 'falls back to everything when asked for a filter it does not have' do
      expect(call('nonsense')[:rows].size).to eq(2)
    end
  end

  describe 'what counts as having a card' do
    it 'carries the copies so the row can say how many you have' do
      own(card(1, name: 'Have'), quantity: 2, foil_quantity: 3)

      expect(row('Have')).to include(owned_qty: 2, owned_foil_qty: 3)
    end

    # the page exists to say what is left to buy, and a proxy is what you print because you have not
    # bought it
    it 'reads a printing held only as a proxy as one you are missing' do
      own(card(1, name: 'Proxied'), quantity: 0, proxy_quantity: 4, proxy_foil_quantity: 1)

      expect(row('Proxied')).to include(owned: false, owned_printings: 0, owned_qty: 0)
      expect(call('missing')[:rows].map { |group| group[:name] }).to eq(['Proxied'])
    end

    it 'ignores staged and wishlist rows, same as the rest of the dashboard' do
      own(card(1, name: 'Staged'), staged: true)
      own(card(2, name: 'Wanted'), needed: true)

      expect(rows.map { |group| group[:owned] }).to eq([false, false])
    end
  end

  describe 'what is not a card you can collect' do
    it 'leaves out tokens and the back face of a double-faced card' do
      card(1, name: 'Real')
      card(2, name: 'Token', is_token: true)
      card(3, name: 'Back Face', card_side: 'b')

      expect(rows.map { |group| group[:name] }).to eq(['Real'])
    end
  end

  it 'reads the whole set in one query' do
    own(card(1))
    card(2)

    queries = track_queries { call }

    expect(queries.size).to eq(1)
  end
end
