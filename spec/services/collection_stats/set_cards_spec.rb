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

    it 'counts a card as missing while any of its printings still is' do
      expect(call('missing')[:rows].map { |group| group[:name] }).to eq(['Want'])
    end

    # the shopping-list reading: a card at 1 of 3 is one you HAVE and one you are still buying, so
    # it belongs in both lists. Filtering missing down to "you own none of it" is what hid the
    # variants somebody opened the page to find
    it 'lists a card you own one printing of under both owned and missing' do
      oracle = SecureRandom.uuid
      own(card(3, name: 'Partial', oracle: oracle))
      card(4, name: 'Partial', oracle: oracle)

      expect(call('owned')[:rows].map { |group| group[:name] }).to eq(%w[Have Partial])
      expect(call('missing')[:rows].map { |group| group[:name] }).to eq(%w[Want Partial])
    end

    it 'labels every toggle off the same pass' do
      expect(call('missing')[:counts]).to eq({ all: 2, owned: 1, missing: 1, foils: 0 })
    end

    it 'falls back to everything when asked for a filter it does not have' do
      expect(call('nonsense')[:rows].size).to eq(2)
    end
  end

  describe 'foils' do
    # no finish factory exists - MagicCardFinish is joined by hand, same as spec/requests/boxsets_spec.rb
    def with_finish(magic_card, name)
      MagicCardFinish.create!(magic_card: magic_card, finish: Finish.find_or_create_by!(name: name))
      magic_card
    end

    it 'says the foil is outstanding on a printing you only have in non-foil' do
      own(with_finish(card(1, name: 'Have'), 'foil'), quantity: 2, foil_quantity: 0)

      expect(row('Have')[:printings].first).to include(foil_available: true, missing_foil: true)
    end

    it 'says nothing about a printing that was never sold in foil' do
      own(with_finish(card(1, name: 'Have'), 'nonfoil'))

      expect(row('Have')[:printings].first).to include(foil_available: false, missing_foil: false)
    end

    it 'counts etched as a foil, same as MagicCard#foil_available?' do
      own(with_finish(card(1, name: 'Etched'), 'etched'), foil_quantity: 1)

      expect(row('Etched')[:printings].first).to include(foil_available: true, missing_foil: false)
    end

    it 'filters to the printings whose foil you are still short' do
      own(with_finish(card(1, name: 'Has Foil'), 'foil'), foil_quantity: 1)
      own(with_finish(card(2, name: 'Needs Foil'), 'foil'), quantity: 1, foil_quantity: 0)
      with_finish(card(3, name: 'No Foil Made'), 'nonfoil')

      expect(call('foils')[:rows].map { |group| group[:name] }).to eq(['Needs Foil'])
      expect(call('foils')[:counts][:foils]).to eq(1)
    end

    it 'asks the same question of a single slot in the visual grid' do
      own(with_finish(with_finish(card(1, name: 'Needs Foil'), 'nonfoil'), 'foil'),
          quantity: 1, foil_quantity: 0)
      own(with_finish(with_finish(card(2, name: 'Has Foil'), 'nonfoil'), 'foil'), foil_quantity: 2)

      result = described_class.call(collection_ids: [collection.id], boxset: set,
                                    filter: 'foils', unit: 'printing')

      expect(result[:rows].map { |slot| [slot[:name], slot[:finish]] })
        .to eq([['Needs Foil', :foil]])
    end

    # the whole reason it is a separate flag: completion is about printings, and a foil you are
    # short must not move the bar this page shares with the completion panel
    it 'leaves the foil gap out of owned and out of missing' do
      own(with_finish(card(1, name: 'Have'), 'foil'), quantity: 1, foil_quantity: 0)

      expect(row('Have')).to include(owned: true, incomplete: false, missing_foils: 1)
      expect(call('missing')[:rows]).to be_empty
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

  # the visual grid is a wall of art and the art is per printing, so folding them there would hide
  # exactly what somebody opened the grid to see - NEO's Jin-Gitaxias is seven pictures, not one
  describe 'at printing unit' do
    subject(:printings) { call_unit[:rows] }

    def call_unit(mode = filter)
      described_class.call(collection_ids: [collection.id], boxset: set, filter: mode,
                           unit: 'printing')
    end

    before do
      oracle = SecureRandom.uuid
      own(card(1, name: 'Agate Assault', oracle: oracle))
      card(3, name: 'Agate Assault', oracle: oracle)
      card(4, name: 'Agate Assault', oracle: oracle)
    end

    it 'gives every printing its own row instead of folding them' do
      expect(printings.size).to eq(3)
      expect(printings.map { |printing| printing[:number] }).to eq(%w[1 3 4])
    end

    # a slot is a printing in a finish - the thing you either have in the binder or do not - so the
    # grid is a checklist and a foil is its own line on it
    describe 'slots' do
      def with_finish(magic_card, name)
        MagicCardFinish.create!(magic_card: magic_card,
                                finish: Finish.find_or_create_by!(name: name))
        magic_card
      end

      it 'gives a printing sold in both finishes a tile each, priced separately' do
        set.magic_cards.destroy_all
        both = with_finish(with_finish(card(1, name: 'Katana', normal_price: 2, foil_price: 9),
                                       'nonfoil'), 'foil')
        own(both, quantity: 1, foil_quantity: 0)

        expect(printings.map { |slot| [slot[:finish], slot[:price], slot[:owned]] })
          .to eq([[:regular, 2, true], [:foil, 9, false]])
      end

      it 'gives a foil-only printing no regular slot to be missing' do
        set.magic_cards.destroy_all
        with_finish(card(1, name: 'Foil Only'), 'foil')

        expect(printings.map { |slot| slot[:finish] }).to eq([:foil])
      end

      # dropping it would silently shrink the set
      it 'falls back to a regular slot when the finishes were never recorded' do
        set.magic_cards.destroy_all
        card(1, name: 'Unknown Finishes')

        expect(printings.map { |slot| slot[:finish] }).to eq([:regular])
      end
    end

    # NEO numbers Jin-Gitaxias 59 and then 307, 371, 427, 445, 513, 514. In plain collector order
    # its seven printings land on five different pages, which is useless to somebody scrolling for
    # variants - the card stays in set order, its variants come with it
    it 'keeps a card and its variants together rather than scattering them by number' do
      other = SecureRandom.uuid
      card(2, name: 'Bakersbane Duo', oracle: other)
      card(5, name: 'Bakersbane Duo', oracle: other)

      expect(printings.map { |printing| [printing[:name], printing[:number]] })
        .to eq([['Agate Assault', '1'], ['Agate Assault', '3'], ['Agate Assault', '4'],
                ['Bakersbane Duo', '2'], ['Bakersbane Duo', '5']])
    end

    # the other reading of missing: you have the card, you do not have this printing of it
    it 'calls a variant of a card you own missing, because you do not have that one' do
      expect(call_unit('missing')[:rows].map { |printing| printing[:number] }).to eq(%w[3 4])
      expect(call_unit('owned')[:rows].map { |printing| printing[:number] }).to eq(['1'])
    end

    it 'counts slots, so the toggle labels what the grid is actually showing' do
      expect(call_unit[:counts]).to eq({ all: 3, owned: 1, missing: 2, foils: 0 })
    end

    it 'falls back to folding when asked for a unit it does not have' do
      result = described_class.call(collection_ids: [collection.id], boxset: set, unit: 'nonsense')

      expect(result[:rows].size).to eq(1)
    end
  end

  it 'reads the whole set in one query' do
    own(card(1))
    card(2)

    queries = track_queries { call }

    expect(queries.size).to eq(1)
  end
end
