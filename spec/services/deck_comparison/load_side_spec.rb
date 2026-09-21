require 'rails_helper'

RSpec.describe DeckComparison::LoadSide, type: :service do
  let(:viewer) { create(:user, username: 'deckowner') }
  let(:deck) { create(:collection, user: viewer, name: 'Atraxa', collection_type: 'commander_deck') }

  def card(name, oracle_id: SecureRandom.uuid, **attributes)
    create(:magic_card, name: name, scryfall_oracle_id: oracle_id, **attributes)
  end

  def row(magic_card, **attributes)
    create(:collection_magic_card, collection: deck, magic_card: magic_card, **attributes)
  end

  def load_deck(deck_id, viewer: self.viewer)
    described_class.call(viewer: viewer, source: 'deck', text: nil, deck_id: deck_id, label: 'A')
  end

  def load_paste(text)
    described_class.call(viewer: nil, source: 'paste', text: text, deck_id: nil, label: 'B')
  end

  def names(side)
    side[:cards].map { |entry| entry[:magic_card].name }
  end

  describe 'a side nobody filled in' do
    it 'is blank for a paste with no text' do
      expect(load_paste("  \n")).to include(label: 'B', source: 'none', blank: true, error: nil, cards: [])
    end

    it 'is blank for an unknown source' do
      side = described_class.call(viewer: viewer, source: 'url', text: '1 Sol Ring', deck_id: deck.id, label: 'A')

      expect(side).to include(source: 'none', blank: true, cards: [])
    end
  end

  describe 'a deck the viewer may not use' do
    let(:refused) do
      { label: 'A', source: 'deck', deck_name: nil, blank: false, error: 'Pick one of your decks.',
        cards: [], ambiguous: [], unresolved: [] }
    end

    it 'refuses a foreign deck, a logged-out viewer, a binder and an unknown id identically' do
      foreign = create(:collection, user: create(:user, username: 'stranger'), collection_type: 'deck')
      binder = create(:collection, user: viewer)
      row(card('Sol Ring'))

      sides = [load_deck(foreign.id), load_deck(deck.id, viewer: nil), load_deck(binder.id), load_deck(0),
               load_deck(nil)]

      expect(sides).to all(eq(refused))
    end
  end

  describe 'an own deck' do
    it 'holds the staged, needed and owned rows' do
      row(card('Staged'), staged: true, quantity: 0, staged_quantity: 1)
      row(card('Needed'), needed: true)
      row(card('Owned'))

      side = load_deck(deck.id)

      expect(side).to include(source: 'deck', deck_name: 'Atraxa', blank: false, error: nil)
      expect(names(side)).to contain_exactly('Staged', 'Needed', 'Owned')
    end

    it 'leaves the sideboard out' do
      row(card('Sol Ring'))
      row(card('Pyroblast'), board_type: 'sideboard')

      expect(names(load_deck(deck.id))).to eq(['Sol Ring'])
    end

    it 'merges rows on one oracle id, summing quantities and keeping the first printing' do
      oracle_id = SecureRandom.uuid
      first = card('Forest', oracle_id: oracle_id, normal_price: 0.25)
      row(first, quantity: 3)
      row(card('Forest', oracle_id: oracle_id), quantity: 2, foil_quantity: 1)

      expect(load_deck(deck.id)[:cards])
        .to eq([{ key: oracle_id, magic_card: first, quantity: 6, board_type: 'mainboard', unit_price: 0.25 }])
    end

    it 'keys a card with no oracle id by its own id' do
      oddball = card('Oddball', oracle_id: nil)
      row(oddball)

      expect(load_deck(deck.id)[:cards].first).to include(key: "card:#{oddball.id}", magic_card: oddball)
    end

    it 'swaps a back face for its front face' do
      oracle_id = SecureRandom.uuid
      front = card('Delver of Secrets', oracle_id: oracle_id, card_side: 'a', card_uuid: 'front-uuid')
      row(card('Insectile Aberration', oracle_id: oracle_id, card_side: 'b', other_face_uuid: 'front-uuid'))

      expect(load_deck(deck.id)[:cards].first).to include(key: oracle_id, magic_card: front)
    end

    it 'keeps commander when any merged row is the commander' do
      oracle_id = SecureRandom.uuid
      row(card('Atraxa', oracle_id: oracle_id))
      row(card('Atraxa', oracle_id: oracle_id), board_type: 'commander')

      expect(load_deck(deck.id)[:cards].first).to include(board_type: 'commander', quantity: 2)
    end
  end

  describe 'a pasted list' do
    it 'reads the commander header and treats every other board as mainboard' do
      atraxa = card('Atraxa')
      ring = card('Sol Ring', normal_price: 1.5)

      side = load_paste("Commander\n1 Atraxa\n\nDeck\n1 Sol Ring")

      expect(side).to include(source: 'paste', deck_name: nil, blank: false, error: nil)
      expect(side[:cards]).to eq(
        [{ key: atraxa.scryfall_oracle_id, magic_card: atraxa, quantity: 1, board_type: 'commander', unit_price: 5.0 },
         { key: ring.scryfall_oracle_id, magic_card: ring, quantity: 1, board_type: 'mainboard', unit_price: 1.5 }]
      )
    end

    it 'drops the sideboard, maybeboard and tokens' do
      card('Sol Ring')
      card('Pyroblast')
      card('Counterspell')
      card('Treasure Map')

      side = load_paste(<<~LIST)
        1 Sol Ring
        Sideboard
        1 Pyroblast
        Maybeboard
        1 Counterspell
        Tokens
        1 Treasure Map
        1 Not A Card
      LIST

      expect(names(side)).to eq(['Sol Ring'])
      expect(side[:unresolved]).to eq([])
    end

    it 'merges two names on one oracle id' do
      oracle_id = SecureRandom.uuid
      card('Fire // Ice', oracle_id: oracle_id, face_name: 'Fire', card_side: 'a')
      card('Fire // Ice', oracle_id: oracle_id, face_name: 'Ice', card_side: 'b')

      side = load_paste("1 Fire // Ice\n2 Ice")

      expect(side[:cards].map { |entry| entry.slice(:key, :quantity) }).to eq([{ key: oracle_id, quantity: 3 }])
    end

    it 'reports ambiguous and unresolved names as typed' do
      card('Fire // Ice', face_name: 'Fire')
      card('Fire // Rain', face_name: 'Fire')

      side = load_paste("2 fire\n3x Sol Rnig")

      expect(side).to include(cards: [], ambiguous: [{ name: 'fire', quantity: 2 }],
                              unresolved: [{ name: 'Sol Rnig', quantity: 3 }])
    end

    it 'shows the cheapest ordinary printing' do
      oracle_id = SecureRandom.uuid
      card('Sol Ring', oracle_id: oracle_id, normal_price: 9)
      cheapest = card('Sol Ring', oracle_id: oracle_id, normal_price: 1)

      expect(load_paste('1 Sol Ring')[:cards].first).to include(magic_card: cheapest, unit_price: 1.0)
    end

    it 'reports a resolved card with no printing as unresolved' do
      card('Sol Ring')
      allow(Decklist::DefaultPrintings).to receive(:call).and_return({})

      expect(load_paste('4 Sol Ring')).to include(cards: [], unresolved: [{ name: 'Sol Ring', quantity: 4 }])
    end

    it 'refuses more than 150 entries' do
      text = Array.new(151) { |index| "1 Card #{index}" }.join("\n")

      expect(load_paste(text)).to include(error: 'Paste at most 150 cards per deck.', cards: [], blank: false)
    end

    it 'does not count dropped boards towards the cap' do
      text = (['1 Sol Ring', 'Maybeboard'] + Array.new(200) { |index| "1 Card #{index}" }).join("\n")
      card('Sol Ring')

      expect(load_paste(text)).to include(error: nil)
    end

    it 'refuses text over 100k characters before parsing it' do
      allow(Decklist::Parse).to receive(:call)

      expect(load_paste('a' * 100_001)).to include(error: 'That list is too long.', cards: [])
      expect(Decklist::Parse).not_to have_received(:call)
    end
  end
end
