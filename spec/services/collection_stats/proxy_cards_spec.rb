require 'rails_helper'

RSpec.describe CollectionStats::ProxyCards, type: :service do
  subject(:result) { call }

  let(:user) { create(:user) }
  let(:binder) { create(:collection, user: user, name: 'Binder') }
  let(:cube) { create(:collection, user: user, name: 'Cube') }
  let(:deck) { create(:collection, user: user, name: 'Legacy Deck', collection_type: 'deck') }
  let(:edh) { create(:collection, user: user, name: 'Atraxa', collection_type: 'commander_deck') }
  let(:oracle) { SecureRandom.uuid }

  def call(filter: 'all', location: 'all', proxy_ids: nil, search_ids: nil)
    all_ids = [binder.id, cube.id, deck.id, edh.id]
    described_class.call(proxy_collection_ids: proxy_ids || all_ids,
                         search_collection_ids: search_ids || all_ids,
                         filter: filter, location: location)
  end

  def printing(name: 'Underground Sea', oracle_id: oracle, **attributes)
    create(:magic_card, { name: name, scryfall_oracle_id: oracle_id, card_number: '286',
                          boxset: create(:boxset) }.merge(attributes))
  end

  def hold(card, collection, **attributes)
    create(:collection_magic_card, { collection: collection, magic_card: card,
                                     quantity: 0 }.merge(attributes))
  end

  def row_for(card, from = result)
    from[:rows].find { |row| row[:id] == card.id }
  end

  describe 'the rows' do
    it 'lists a printing you hold a proxy of' do
      card = printing
      hold(card, binder, proxy_quantity: 2, proxy_foil_quantity: 1)

      expect(result[:rows].size).to eq(1)
      expect(row_for(card)).to include(name: 'Underground Sea', proxy_qty: 2, proxy_foil_qty: 1)
    end

    it 'leaves out a printing held only as a real card' do
      hold(printing, binder, quantity: 3)

      expect(result[:rows]).to be_empty
    end

    # a row is a printing, not a card - you proxied a specific version and that is what is in the sleeve
    it 'keeps two proxied printings of the same card apart' do
      alpha = printing(card_number: '286')
      revised = printing(card_number: '286b')
      hold(alpha, binder, proxy_quantity: 1)
      hold(revised, binder, proxy_quantity: 1)

      expect(result[:rows].size).to eq(2)
    end

    it 'names every collection holding the proxy' do
      card = printing
      hold(card, binder, proxy_quantity: 1)
      hold(card, cube, proxy_quantity: 2)

      expect(row_for(card)[:proxy_locations].map { |location| location[:collection_name] })
        .to eq(%w[Binder Cube])
      expect(row_for(card)[:proxy_qty]).to eq(3)
    end

    # collection_magic_cards has no unique index on (collection_id, magic_card_id), so one binder can
    # hold the same printing on two rows. Two lines reading "Binder x1" is a data artefact.
    it 'folds two rows for the same printing in one collection into one location' do
      card = printing
      hold(card, binder, proxy_quantity: 1)
      hold(card, binder, proxy_quantity: 2)

      expect(row_for(card)[:proxy_locations].size).to eq(1)
      expect(row_for(card)[:proxy_locations].first[:qty]).to eq(3)
    end

    it 'ignores staged and wishlist rows, same as the rest of the dashboard' do
      hold(printing, binder, proxy_quantity: 1, staged: true)
      hold(printing(card_number: '2'), binder, proxy_quantity: 1, needed: true)

      expect(result[:rows]).to be_empty
    end

    it 'sorts by name' do
      hold(printing(name: 'Zealot', oracle_id: SecureRandom.uuid), binder, proxy_quantity: 1)
      hold(printing(name: 'Ancestral', oracle_id: SecureRandom.uuid), binder, proxy_quantity: 1)

      expect(result[:rows].map { |row| row[:name] }).to eq(%w[Ancestral Zealot])
    end
  end

  describe 'finding the real card' do
    it 'reports proxy only when no real copy exists anywhere' do
      card = printing
      hold(card, binder, proxy_quantity: 1)

      expect(row_for(card)).to include(has_real: false, real_same_printing: false,
                                       real_other_printing: false)
      expect(row_for(card)[:real_locations]).to be_empty
    end

    it 'finds a real copy of the same printing in another collection' do
      card = printing
      hold(card, binder, proxy_quantity: 1)
      hold(card, cube, quantity: 1, foil_quantity: 1)

      expect(row_for(card)).to include(has_real: true, real_same_printing: true,
                                       real_other_printing: false, real_qty: 1, real_foil_qty: 1)
      expect(row_for(card)[:real_locations].first).to include(collection_name: 'Cube',
                                                              same_printing: true)
    end

    # the finding the page exists for: you already own the card, just not the version you proxied
    it 'finds a real copy of a different printing sharing the oracle id' do
      proxied = printing(card_number: '286')
      other = printing(card_number: '286b')
      hold(proxied, binder, proxy_quantity: 1)
      hold(other, cube, quantity: 1)

      expect(row_for(proxied)).to include(has_real: true, real_same_printing: false,
                                          real_other_printing: true)
      expect(row_for(proxied)[:real_locations].first).to include(same_printing: false)
    end

    it 'reports both when the card is owned in this printing and another' do
      proxied = printing(card_number: '286')
      other = printing(card_number: '286b')
      hold(proxied, binder, proxy_quantity: 1)
      hold(proxied, binder, quantity: 1)
      hold(other, cube, quantity: 1)

      expect(row_for(proxied)).to include(real_same_printing: true, real_other_printing: true)
    end

    it 'does not treat a proxy elsewhere as a real copy' do
      card = printing
      hold(card, binder, proxy_quantity: 1)
      hold(card, cube, proxy_quantity: 4)

      expect(row_for(card)[:has_real]).to be(false)
    end

    it 'does not treat a different card as a real copy' do
      card = printing
      hold(card, binder, proxy_quantity: 1)
      hold(printing(name: 'Tundra', oracle_id: SecureRandom.uuid), cube, quantity: 1)

      expect(row_for(card)[:has_real]).to be(false)
    end

    # back faces carry the same oracle id as their front, so without the card_side guard the b-face
    # row of a double-faced card reads as a real copy nobody owns
    it 'does not count a back face as a real copy' do
      card = printing(card_side: 'a')
      hold(card, binder, proxy_quantity: 1)
      hold(printing(card_side: 'b'), cube, quantity: 1)

      expect(row_for(card)[:has_real]).to be(false)
    end

    describe 'when scryfall_oracle_id has not been backfilled' do
      it 'falls back to matching on the name' do
        card = printing(oracle_id: nil)
        hold(card, binder, proxy_quantity: 1)
        hold(printing(oracle_id: nil, card_number: '286b'), cube, quantity: 1)

        expect(row_for(card)).to include(has_real: true, real_other_printing: true)
      end

      it 'does not merge two different unbackfilled cards' do
        card = printing(name: 'Underground Sea', oracle_id: nil)
        hold(card, binder, proxy_quantity: 1)
        hold(printing(name: 'Tundra', oracle_id: nil), cube, quantity: 1)

        expect(row_for(card)[:has_real]).to be(false)
      end
    end
  end

  # the picker narrows which proxies are LISTED; it never narrows where a real copy counts as found.
  # searching one collection for both is what would report "proxy only" for a card sitting in the
  # binder next door.
  describe 'the two collection scopes' do
    it 'lists only the selected collection but still finds real copies outside it' do
      card = printing
      hold(card, binder, proxy_quantity: 1)
      hold(card, cube, proxy_quantity: 5)
      hold(card, cube, quantity: 1)

      narrowed = call(proxy_ids: [binder.id], search_ids: [binder.id, cube.id])

      expect(narrowed[:rows].size).to eq(1)
      expect(row_for(card, narrowed)[:proxy_qty]).to eq(1)
      expect(row_for(card, narrowed)).to include(has_real: true, real_same_printing: true)
    end

    it 'defaults the search scope to the proxy scope when none is given' do
      card = printing
      hold(card, binder, proxy_quantity: 1)
      hold(card, cube, quantity: 1)

      narrowed = described_class.call(proxy_collection_ids: [binder.id])

      expect(narrowed[:rows].first[:has_real]).to be(false)
    end

    it 'returns nothing when there are no collections' do
      expect(described_class.call(proxy_collection_ids: [])[:rows]).to be_empty
    end
  end

  describe 'filters and counts' do
    before do
      hold(printing(name: 'Bare', oracle_id: SecureRandom.uuid), binder, proxy_quantity: 1)

      same = printing(name: 'Same', oracle_id: SecureRandom.uuid)
      hold(same, binder, proxy_quantity: 1)
      hold(same, cube, quantity: 1)

      other_oracle = SecureRandom.uuid
      hold(printing(name: 'Other', oracle_id: other_oracle, card_number: '1'), binder,
           proxy_quantity: 1)
      hold(printing(name: 'Other', oracle_id: other_oracle, card_number: '2'), cube, quantity: 1)
    end

    it 'counts every row regardless of the filter in force' do
      expect(call(filter: 'proxy_only')[:counts])
        .to eq(all: 3, proxy_only: 1, other_printing: 1)
    end

    it 'narrows to proxies with nothing real behind them' do
      expect(call(filter: 'proxy_only')[:rows].map { |row| row[:name] }).to eq(['Bare'])
    end

    # there is no "real owned" button because it would be exactly this - the complement of the
    # shopping list, reconstructible from two numbers already on screen
    it 'leaves the backed rows derivable from all minus proxy_only' do
      all = call[:rows].map { |row| row[:name] }
      bare = call(filter: 'proxy_only')[:rows].map { |row| row[:name] }

      expect(all - bare).to match_array(%w[Other Same])
      expect(call[:counts][:all] - call[:counts][:proxy_only]).to eq(2)
    end

    # other_printing is a subset of the backed rows rather than their whole, which is why it stays
    it 'narrows to proxies whose real copy is a different printing' do
      expect(call(filter: 'other_printing')[:rows].map { |row| row[:name] }).to eq(['Other'])
    end

    it 'falls back to all for an unrecognised filter' do
      expect(call(filter: 'nonsense')[:rows].size).to eq(3)
    end
  end

  # a deck is collection_type 'deck' or anything ending _deck - Collection.deck_type?, the same
  # definition the Collection.decks scope is written from
  describe 'the deck axis' do
    it 'marks a proxy location in a deck' do
      card = printing
      hold(card, deck, proxy_quantity: 1)

      expect(row_for(card)).to include(in_deck: true, outside_deck: false)
      expect(row_for(card)[:proxy_locations].first[:deck]).to be(true)
    end

    it 'treats a commander deck as a deck' do
      card = printing
      hold(card, edh, proxy_quantity: 1)

      expect(described_class.call(proxy_collection_ids: [edh.id])[:rows].first[:in_deck]).to be(true)
    end

    it 'does not treat a binder as a deck' do
      card = printing
      hold(card, binder, proxy_quantity: 1)

      expect(row_for(card)).to include(in_deck: false, outside_deck: true)
    end

    it 'narrows to proxies sleeved in a deck' do
      sleeved = printing(name: 'Sleeved', oracle_id: SecureRandom.uuid)
      hold(sleeved, deck, proxy_quantity: 1)
      hold(printing(name: 'Spare', oracle_id: SecureRandom.uuid), binder, proxy_quantity: 1)

      expect(call(location: 'decks')[:rows].map { |row| row[:name] }).to eq(['Sleeved'])
    end

    it 'narrows to proxies sitting outside a deck' do
      hold(printing(name: 'Sleeved', oracle_id: SecureRandom.uuid), deck, proxy_quantity: 1)
      hold(printing(name: 'Spare', oracle_id: SecureRandom.uuid), binder, proxy_quantity: 1)

      expect(call(location: 'binders')[:rows].map { |row| row[:name] }).to eq(['Spare'])
    end

    # a row is a printing, not a copy - three sleeved and one spare is genuinely both, and forcing it
    # to pick a side would hide it from whichever list you happened to open
    it 'keeps a printing proxied in both places in both lists' do
      card = printing(name: 'Both')
      hold(card, deck, proxy_quantity: 3)
      hold(card, binder, proxy_quantity: 1)

      expect(call(location: 'decks')[:rows].map { |row| row[:name] }).to eq(['Both'])
      expect(call(location: 'binders')[:rows].map { |row| row[:name] }).to eq(['Both'])
    end

    # deck-ness is asked of the PROXY locations - where the real card lives is the other axis
    it 'does not put a proxy in the deck list because the real copy is in a deck' do
      card = printing
      hold(card, binder, proxy_quantity: 1)
      hold(card, deck, quantity: 1)

      expect(row_for(card)).to include(in_deck: false, real_in_deck: true)
      expect(call(location: 'decks')[:rows]).to be_empty
    end

    it 'falls back to all for an unrecognised location' do
      hold(printing, binder, proxy_quantity: 1)

      expect(call(location: 'nonsense')[:rows].size).to eq(1)
    end
  end

  # each toggle is counted against the other axis, so its numbers match the list a click would give
  describe 'counts across both axes' do
    before do
      bare_deck = printing(name: 'BareDeck', oracle_id: SecureRandom.uuid)
      hold(bare_deck, deck, proxy_quantity: 1)

      covered_deck = printing(name: 'CoveredDeck', oracle_id: SecureRandom.uuid)
      hold(covered_deck, deck, proxy_quantity: 1)
      hold(covered_deck, cube, quantity: 1)

      bare_binder = printing(name: 'BareBinder', oracle_id: SecureRandom.uuid)
      hold(bare_binder, binder, proxy_quantity: 1)
    end

    it 'counts the status buttons within the chosen location' do
      expect(call(location: 'decks')[:counts])
        .to eq(all: 2, proxy_only: 1, other_printing: 0)
    end

    it 'counts the location buttons within the chosen status' do
      expect(call(filter: 'proxy_only')[:location_counts])
        .to eq(all: 2, decks: 1, binders: 1, swappable: 0)
    end

    it 'returns the rows both axes agree on' do
      expect(call(filter: 'proxy_only', location: 'decks')[:rows].map { |row| row[:name] })
        .to eq(['BareDeck'])
    end

    # the tiles sit outside the turbo frame and do not re-render when a toggle moves
    it 'leaves the totals describing every proxy regardless of either axis' do
      expect(call(filter: 'proxy_only', location: 'decks')[:totals])
        .to include(printings: 3, copies: 3, proxy_only: 2)
    end
  end

  # the actionable list: a proxy sleeved in a deck whose real copy is free to be moved into it
  describe 'swap ready' do
    it 'finds a deck proxy whose real copy sits in a binder' do
      card = printing
      hold(card, deck, proxy_quantity: 1)
      hold(card, binder, quantity: 1)

      expect(row_for(card)).to include(swappable: true, real_outside_deck: true)
      expect(call(location: 'swappable')[:rows].size).to eq(1)
    end

    it 'counts a real copy in another printing, since any real copy can be sleeved' do
      proxied = printing(card_number: '286')
      hold(proxied, deck, proxy_quantity: 1)
      hold(printing(card_number: '286b'), binder, quantity: 1)

      expect(row_for(proxied)[:swappable]).to be(true)
    end

    # the whole point of the filter: a real card already sleeved elsewhere is spoken for, and taking
    # it leaves a hole in that deck instead of closing one here
    it 'skips a proxy whose only real copy is in another deck' do
      card = printing
      hold(card, deck, proxy_quantity: 1)
      hold(card, edh, quantity: 1)

      expect(row_for(card)).to include(swappable: false, has_real: true, real_in_deck: true,
                                       real_outside_deck: false)
      expect(call(location: 'swappable')[:rows]).to be_empty
    end

    it 'takes it when one real copy is spoken for and another is not' do
      card = printing
      hold(card, deck, proxy_quantity: 1)
      hold(card, edh, quantity: 1)
      hold(card, binder, quantity: 1)

      expect(row_for(card)[:swappable]).to be(true)
    end

    it 'skips a proxy that is not in a deck at all' do
      card = printing
      hold(card, binder, proxy_quantity: 1)
      hold(card, cube, quantity: 1)

      expect(row_for(card)[:swappable]).to be(false)
    end

    it 'skips a proxy with no real copy anywhere' do
      card = printing
      hold(card, deck, proxy_quantity: 1)

      expect(row_for(card)[:swappable]).to be(false)
    end

    # nothing to move: the real card is already sleeved in the very deck the proxy is in
    it 'skips a proxy whose real copy is in the same deck' do
      card = printing
      hold(card, deck, proxy_quantity: 1)
      hold(card, deck, quantity: 1)

      expect(row_for(card)[:swappable]).to be(false)
    end

    it 'is counted alongside the other status buttons' do
      swap = printing(name: 'Swap', oracle_id: SecureRandom.uuid)
      hold(swap, deck, proxy_quantity: 1)
      hold(swap, binder, quantity: 1)
      hold(printing(name: 'Bare', oracle_id: SecureRandom.uuid), deck, proxy_quantity: 1)

      expect(call[:counts]).to include(all: 2, proxy_only: 1)
      expect(call[:location_counts]).to include(swappable: 1)
    end

    # it sits on the deck axis rather than beside the real-copy filters, so the one combination that
    # could only ever be empty - swap-ready proxies OUTSIDE a deck - is now unreachable instead of
    # merely honest about being zero
    it 'is an option on the location axis, not the status one' do
      expect(described_class::LOCATIONS).to include('swappable')
      expect(described_class::FILTERS).not_to include('swappable')
    end

    it 'is a strict narrowing of the deck list' do
      swap = printing(name: 'Swap', oracle_id: SecureRandom.uuid)
      hold(swap, deck, proxy_quantity: 1)
      hold(swap, binder, quantity: 1)
      hold(printing(name: 'Stuck', oracle_id: SecureRandom.uuid), deck, proxy_quantity: 1)

      in_decks = call(location: 'decks')[:rows].map { |row| row[:name] }
      swappable = call(location: 'swappable')[:rows].map { |row| row[:name] }

      expect(swappable).to eq(['Swap'])
      expect(swappable - in_decks).to be_empty
    end
  end

  describe 'totals' do
    it 'counts copies and printings, not rows in the database' do
      card = printing
      hold(card, binder, proxy_quantity: 2, proxy_foil_quantity: 1)
      hold(card, cube, proxy_quantity: 1)

      expect(result[:totals]).to include(copies: 4, printings: 1)
    end

    # proxies carry no value anywhere else in the app - this page is where that number IS the question
    it 'prices the pile off the proxy fallback rule' do
      hold(printing(normal_price: 3, foil_price: 10), binder, proxy_quantity: 2,
                                                              proxy_foil_quantity: 1)

      expect(result[:totals][:value]).to eq(16)
    end

    it 'prices a foil-only printing off its foil price' do
      hold(printing(normal_price: 0, foil_price: 8), binder, proxy_quantity: 2)

      expect(result[:totals][:value]).to eq(16)
    end

    it 'counts only the proxy-only rows toward the cost to replace' do
      hold(printing(name: 'Bare', oracle_id: SecureRandom.uuid, normal_price: 5), binder,
           proxy_quantity: 1)

      covered = printing(name: 'Covered', oracle_id: SecureRandom.uuid, normal_price: 100)
      hold(covered, binder, proxy_quantity: 1)
      hold(covered, cube, quantity: 1)

      expect(result[:totals]).to include(value: 105, cost_to_replace: 5, proxy_only: 1)
    end
  end
end
