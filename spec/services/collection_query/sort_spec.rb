require 'rails_helper'

RSpec.describe CollectionQuery::Sort, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let!(:card_a) { create(:magic_card, name: 'Alpha', card_number: '1', normal_price: 10.0) }
  let!(:card_b) { create(:magic_card, name: 'Beta', card_number: '2', normal_price: 5.0) }
  let!(:card_c) { create(:magic_card, name: 'Gamma', card_number: 'A3', normal_price: 20.0) }

  before do
    create(:collection_magic_card, collection: collection, magic_card: card_a, quantity: 1, foil_quantity: 0)
    create(:collection_magic_card, collection: collection, magic_card: card_b, quantity: 2, foil_quantity: 0)
    create(:collection_magic_card, collection: collection, magic_card: card_c, quantity: 1, foil_quantity: 0)
  end

  let(:cards) { MagicCard.where(id: [card_a.id, card_b.id, card_c.id]) }

  context 'when sorting by card number' do
    it 'sorts numeric card numbers first, non-numeric at end' do
      result = described_class.call(cards: cards, sort_by: :id)

      expect(result.map(&:name)).to eq(%w[Alpha Beta Gamma])
    end

    # the whole point of the SQL sort: the caller pages with LIMIT/OFFSET, so ordering in Ruby would
    # have to load the entire set first
    it 'returns a relation the caller can still page' do
      result = described_class.call(cards: cards, sort_by: :id)

      expect(result).to be_a(ActiveRecord::Relation)
      expect(result.limit(1).map(&:name)).to eq(['Alpha'])
    end

    it 'orders numerically rather than lexically' do
      ten = create(:magic_card, name: 'Ten', card_number: '10')
      cards = MagicCard.where(id: [card_a.id, card_b.id, ten.id])

      result = described_class.call(cards: cards, sort_by: :id)

      expect(result.map(&:card_number)).to eq(%w[1 2 10])
    end

    # Integer("12a") raises, so it belongs with the non-numerics - not sorted as 12, which is what
    # stripping the non-digits would do
    it 'pushes mixed alphanumeric card numbers to the end with the other non-numerics' do
      mixed = create(:magic_card, name: 'Mixed', card_number: '12a')
      thirteen = create(:magic_card, name: 'Thirteen', card_number: '13')
      cards = MagicCard.where(id: [card_a.id, mixed.id, thirteen.id])

      result = described_class.call(cards: cards, sort_by: :id)

      expect(result.map(&:card_number)).to eq(%w[1 13 12a])
    end

    it 'ignores any ordering the incoming relation already carried' do
      result = described_class.call(cards: cards.order(name: :desc), sort_by: :id)

      expect(result.map(&:name)).to eq(%w[Alpha Beta Gamma])
    end

    # every card_number lands in the same non-numeric bucket, which is where the Ruby sort_by was
    # unstable: each page re-sorted from scratch, so a card could appear on two pages while another
    # was skipped entirely
    context 'when no card number is numeric' do
      let!(:non_numeric) do
        %w[W17-9 E02-41 MIC-170 GN3-12].map { |num| create(:magic_card, card_number: num) }
      end

      let(:cards) { MagicCard.where(id: non_numeric.map(&:id)) }

      it 'pages deterministically without duplicating or skipping cards' do
        result = described_class.call(cards: cards, sort_by: :id)

        first_page = result.limit(2).map(&:id)
        second_page = result.offset(2).limit(2).map(&:id)

        expect(first_page + second_page).to eq(result.map(&:id))
        expect((first_page + second_page).uniq.size).to eq(4)
      end

      it 'returns the same order on repeated queries' do
        result = described_class.call(cards: cards, sort_by: :id)

        expect(result.map(&:id)).to eq(result.reload.map(&:id))
      end
    end

    # card_number repeats across boxsets, so it cannot be the last tiebreak
    context 'when two cards share a card number' do
      let!(:duplicates) { Array.new(3) { create(:magic_card, card_number: '5') } }

      let(:cards) { MagicCard.where(id: duplicates.map(&:id)) }

      it 'falls back to id so tied rows keep a stable order' do
        result = described_class.call(cards: cards, sort_by: :id)

        expect(result.map(&:id)).to eq(duplicates.map(&:id).sort)
      end
    end
  end

  context 'when sorting by price' do
    it 'sorts by total_value DESC' do
      result = described_class.call(cards: cards, sort_by: :price)
      names = result.map(&:name)
      expect(names.first).to eq('Gamma')
    end
  end

  context 'with unknown sort_by' do
    it 'returns cards unmodified' do
      result = described_class.call(cards: cards, sort_by: :unknown)
      expect(result).to eq(cards)
    end
  end
end
