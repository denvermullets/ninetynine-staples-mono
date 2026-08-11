require 'rails_helper'

RSpec.describe CollectionStats::TopCards, type: :service do
  subject(:result) { described_class.call(collection_ids: [collection.id]) }

  let(:collection) { create(:collection) }

  def add(name, price: 1, quantity: 1, **card_attrs)
    card = create(:magic_card, name: name, normal_price: price, **card_attrs)
    create(:collection_magic_card, collection: collection, magic_card: card, quantity: quantity)
    card
  end

  def names(list)
    result[list].map { |row| row[:name] }
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
    # the entire justification for the two ROW_NUMBER windows - rank these separately and this fails
    it 'answers both rankings in one query' do
      add('Sol Ring', price: 5, quantity: 4)

      queries = track_queries { result }

      expect(queries.size).to eq(1)
      expect(result[:by_value]).not_to be_empty
      expect(result[:by_copies]).not_to be_empty
    end

    # "your most valuable card" has to mean a card you could sell, or the list is a ranking of what
    # you chose to proxy - which is exactly the expensive stuff, so it would take over the whole list
    it 'ranks on real copies, so a proxy-only card never places by value' do
      real = create(:magic_card, name: 'Sol Ring', normal_price: 5)
      create(:collection_magic_card, collection: collection, magic_card: real, quantity: 1)
      proxied = create(:magic_card, name: 'Underground Sea', normal_price: 900)
      create(:collection_magic_card, collection: collection, magic_card: proxied,
                                     quantity: 0, proxy_quantity: 4)

      expect(names(:by_value)).to eq(['Sol Ring'])
      expect(result[:by_value].first[:value]).to eq(5)
    end

    # the copies list is a count question, so the proxies it dropped from the value list stay here
    it 'still counts proxy copies in the hoard list' do
      card = create(:magic_card, name: 'Underground Sea', normal_price: 900)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 0, proxy_quantity: 4)

      expect(names(:by_copies)).to eq(['Underground Sea'])
      expect(result[:by_copies].first[:copies]).to eq(4)
    end

    it 'lets one card place in both lists' do
      add('Sol Ring', price: 50, quantity: 9)
      add('Forest', price: 0.1, quantity: 2)

      expect(names(:by_value).first).to eq('Sol Ring')
      expect(names(:by_copies).first).to eq('Sol Ring')
    end
  end

  describe 'ranking by value' do
    it 'ranks on total value rather than unit price' do
      add('Pricey Single', price: 40, quantity: 1)
      add('Cheap Playset', price: 15, quantity: 4)

      expect(names(:by_value)).to eq(['Cheap Playset', 'Pricey Single'])
    end

    it 'counts every finish in a card total' do
      card = create(:magic_card, name: 'Both Finishes', normal_price: 2, foil_price: 30)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1,
                                     foil_quantity: 1)

      expect(result[:by_value].first[:value]).to eq(32)
      expect(result[:by_value].first[:copies]).to eq(2)
    end

    it 'sums the same printing held in two collections' do
      other = create(:collection, user: collection.user)
      card = add('Split Across Binders', price: 10, quantity: 2)
      create(:collection_magic_card, collection: other, magic_card: card, quantity: 3)

      expect(described_class.call(collection_ids: [collection.id, other.id])[:by_value].first)
        .to include(copies: 5, value: 50)
    end

    it 'keeps the list to the top ten' do
      12.times { |n| add("Card #{n}", price: 100 - n) }

      expect(result[:by_value].size).to eq(described_class::TOP)
      expect(names(:by_value)).to include('Card 0')
      expect(names(:by_value)).not_to include('Card 11')
    end

    it 'leaves worthless cards out rather than padding the list with them' do
      add('Worth Something', price: 5)
      add('Worth Nothing', price: 0, foil_price: 0)

      expect(names(:by_value)).to eq(['Worth Something'])
    end
  end

  describe 'ranking by copies' do
    it 'ranks on copies rather than value' do
      add('Bulk Common', price: 0.05, quantity: 40)
      add('The Expensive One', price: 400, quantity: 1)

      expect(names(:by_copies)).to eq(['Bulk Common', 'The Expensive One'])
    end

    it 'counts proxies as copies you are hoarding' do
      card = create(:magic_card, name: 'Proxied Dual', normal_price: 300)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 0,
                                     proxy_quantity: 6)

      expect(result[:by_copies].first).to include(name: 'Proxied Dual', copies: 6)
    end

    it 'keeps the list to the top ten' do
      12.times { |n| add("Card #{n}", quantity: 50 - n) }

      expect(result[:by_copies].size).to eq(described_class::TOP)
    end
  end

  describe 'basic lands' do
    def add_basic(name, quantity: 60, price: 0.1)
      card = add(name, price: price, quantity: quantity)
      card.super_types << SuperType.find_or_create_by!(name: 'Basic')
      card
    end

    it 'leaves them out of the copies list - nobody hoards 60 Forests on purpose' do
      add_basic('Forest')
      add('Sol Ring', quantity: 4)

      expect(names(:by_copies)).to eq(['Sol Ring'])
    end

    it 'still ranks them by value, where a foil basic belongs' do
      add_basic('Foil Forest', quantity: 1, price: 40)
      add('Sol Ring', price: 5)

      expect(names(:by_value)).to eq(['Foil Forest', 'Sol Ring'])
    end

    # they are cards you own, so dropping them from the denominator would inflate the headline
    it 'keeps their value in the concentration denominator' do
      add_basic('Forest', quantity: 60, price: 1)
      add('Sol Ring', price: 40)

      expect(result[:top_value_share]).to eq(100.0)
      expect(result[:by_value].sum { |row| row[:value] }).to eq(100)
    end

    it 'catches a basic by its supertype rather than its name' do
      add_basic('Snow-Covered Forest')
      add('Sol Ring', quantity: 4)

      expect(names(:by_copies)).to eq(['Sol Ring'])
    end

    it 'does not push a nonbasic land off the copies list' do
      add_basic('Forest')
      11.times { |n| add("Card #{n}", quantity: 20 - n) }

      expect(result[:by_copies].size).to eq(described_class::TOP)
      expect(names(:by_copies)).not_to include('Forest')
    end

    it 'leaves the copies list short rather than backfilling it with basics' do
      add_basic('Forest')
      add('Sol Ring', quantity: 4)
      add('Arcane Signet', quantity: 2)

      expect(names(:by_copies)).to eq(['Sol Ring', 'Arcane Signet'])
    end
  end

  describe 'value concentration' do
    # $75 whale + 25 $1 fillers is a $100 collection; the top ten is the whale and nine fillers
    it 'reports the top ten as a share of the whole collection, not of themselves' do
      add('Whale', price: 75)
      25.times { |n| add("Filler #{n}", price: 1) }

      expect(result[:top_value_share]).to eq(84.0)
    end

    it 'is 100% when the collection is smaller than the top ten' do
      add('Only Card', price: 10)

      expect(result[:top_value_share]).to eq(100.0)
    end

    it 'does not divide by zero on a collection worth nothing' do
      add('Worthless', price: 0, foil_price: 0)

      expect(result[:top_value_share]).to eq(0.0)
    end
  end

  describe 'row contents' do
    it 'carries the art and set glyph the list renders' do
      boxset = create(:boxset, name: 'Alpha', keyrune_code: 'LEA')
      add('Black Lotus', price: 9, boxset: boxset, image_small: 'small.jpg',
                         image_large: 'large.jpg')

      expect(result[:by_value].first).to include(
        set_name: 'Alpha', icon: 'no-tailwind ss ss-lea ss-fw',
        image: 'small.jpg', image_large: 'large.jpg'
      )
    end

    # a card with only one cached image still has to have something to hover
    it 'falls back to the thumbnail when there is no large art' do
      add('Half Cached', price: 9, image_small: 'small.jpg', image_large: nil)

      expect(result[:by_value].first[:image_large]).to eq('small.jpg')
    end
  end

  describe 'an empty scope' do
    it 'returns both lists empty without touching the database' do
      queries = track_queries { described_class.call(collection_ids: []) }

      expect(queries).to be_empty
      expect(described_class.call(collection_ids: []))
        .to eq(by_value: [], by_copies: [], top_value_share: 0.0)
    end
  end

  describe 'the collection scope' do
    it 'ignores staged and needed rows the way every other panel does' do
      staged = create(:magic_card, name: 'Deck Scratch', normal_price: 500)
      create(:collection_magic_card, collection: collection, magic_card: staged, quantity: 1,
                                     staged: true)
      add('Actually Owned', price: 1)

      expect(names(:by_value)).to eq(['Actually Owned'])
    end
  end
end
