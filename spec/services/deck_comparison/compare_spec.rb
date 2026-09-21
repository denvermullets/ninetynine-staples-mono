require 'rails_helper'

# sides are built by hand in the shape DeckComparison::LoadSide returns; the diff never touches the
# database, so a magic card here is just a name
RSpec.describe DeckComparison::Compare, type: :service do
  let(:printing) { Struct.new(:name) }

  def entry(key, name: key, quantity: 1, board_type: 'mainboard', unit_price: 1.0)
    { key: key, magic_card: printing.new(name), quantity: quantity, board_type: board_type, unit_price: unit_price }
  end

  def side(source, *cards)
    { source: source, cards: cards }
  end

  def names(rows)
    rows.map { |row| row.magic_card.name }
  end

  describe 'partitioning' do
    let(:result) do
      described_class.call(side_a: side('paste', entry('sol'), entry('forest'), entry('card:7')),
                           side_b: side('paste', entry('forest'), entry('7'), entry('island')))
    end

    it 'puts cards on both sides in shared and the rest in the only tabs' do
      expect(names(result[:tabs][:shared])).to eq(%w[forest])
      expect(names(result[:tabs][:only_a])).to contain_exactly('sol', 'card:7')
      expect(names(result[:tabs][:only_b])).to contain_exactly('7', 'island')
    end

    it 'leaves the absent side\'s quantity nil' do
      expect(result[:tabs][:only_a].map(&:quantity_b)).to all(be_nil)
      expect(result[:tabs][:only_b].map(&:quantity_a)).to all(be_nil)
    end

    it 'puts everything in the other only tab when a side is empty' do
      result = described_class.call(side_a: side('none'), side_b: side('paste', entry('sol'), entry('forest')))

      expect(result[:tabs][:shared]).to be_empty
      expect(result[:tabs][:only_a]).to be_empty
      expect(names(result[:tabs][:only_b])).to eq(%w[sol forest])
    end
  end

  describe 'differing quantities' do
    it 'keeps the card shared and carries both counts' do
      result = described_class.call(side_a: side('paste', entry('forest', quantity: 12)),
                                    side_b: side('paste', entry('forest', quantity: 9)))

      expect(result[:tabs][:shared].map(&:quantity_label)).to eq(['12 / 9'])
      expect(result[:tabs][:only_a] + result[:tabs][:only_b]).to be_empty
    end

    it 'shows a single number when the counts agree' do
      result = described_class.call(side_a: side('paste', entry('sol')), side_b: side('paste', entry('sol')))

      expect(result[:tabs][:shared].first.quantity_label).to eq('1')
    end
  end

  describe 'which printing a shared card shows' do
    def shared(source_a, source_b)
      described_class.call(side_a: side(source_a, entry('sol', name: 'from A', unit_price: 1.0)),
                           side_b: side(source_b, entry('sol', name: 'from B', unit_price: 5.0)))[:tabs][:shared].first
    end

    it 'uses the deck\'s when the deck is side A' do
      expect(shared('deck', 'paste')).to have_attributes(magic_card: have_attributes(name: 'from A'), unit_price: 1.0)
    end

    it 'uses the deck\'s when the deck is side B' do
      expect(shared('paste', 'deck')).to have_attributes(magic_card: have_attributes(name: 'from B'), unit_price: 5.0)
    end

    it 'uses A\'s for two decks' do
      expect(shared('deck', 'deck').magic_card.name).to eq('from A')
    end

    it 'uses A\'s for two pastes' do
      expect(shared('paste', 'paste').magic_card.name).to eq('from A')
    end
  end

  describe 'the commander' do
    it 'is promoted when only side B marks it' do
      result = described_class.call(side_a: side('paste', entry('atraxa')),
                                    side_b: side('paste', entry('atraxa', board_type: 'commander')))

      expect(result[:tabs][:shared].first.board_type).to eq('commander')
    end

    it 'is promoted when only side A marks it' do
      result = described_class.call(side_a: side('paste', entry('atraxa', board_type: 'commander')),
                                    side_b: side('deck', entry('atraxa')))

      expect(result[:tabs][:shared].first.board_type).to eq('commander')
    end

    it 'otherwise takes side A\'s board' do
      result = described_class.call(side_a: side('paste', entry('sol', board_type: 'mainboard')),
                                    side_b: side('deck', entry('sol', board_type: nil)))

      expect(result[:tabs][:shared].first.board_type).to eq('mainboard')
    end
  end

  describe 'stats' do
    let(:result) do
      described_class.call(
        side_a: side('paste', entry('forest', quantity: 12, unit_price: 0.5), entry('sol', unit_price: 2.0)),
        side_b: side('paste', entry('forest', quantity: 9, unit_price: 0.25), entry('island', quantity: 3))
      )
    end

    it 'counts cards, copies and value per tab' do
      expect(result[:stats]).to eq(shared: { cards: 1, quantity: 12, value: 6.0 },
                                   only_a: { cards: 1, quantity: 1, value: 2.0 },
                                   only_b: { cards: 1, quantity: 3, value: 3.0 })
    end
  end
end
