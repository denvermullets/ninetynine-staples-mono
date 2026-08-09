require 'rails_helper'

RSpec.describe CollectionQuery::PageRows, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let(:second_collection) { create(:collection, user: user) }
  let(:boxset) { create(:boxset, code: 'TST') }

  let!(:bolt) { create(:magic_card, name: 'Lightning Bolt', card_number: '10', normal_price: 10.0, boxset: boxset) }
  let!(:ritual) { create(:magic_card, name: 'Dark Ritual', card_number: '2', normal_price: 5.0, boxset: boxset) }
  let!(:mox) do
    create(:magic_card, name: 'Mox Pearl', card_number: '3', normal_price: 1.0, foil_price: 99.0, boxset: boxset)
  end

  before do
    create(:collection_magic_card, collection: collection, magic_card: bolt, quantity: 2, foil_quantity: 0)
    create(:collection_magic_card, collection: second_collection, magic_card: bolt, quantity: 3, foil_quantity: 0)
    create(:collection_magic_card, collection: collection, magic_card: ritual, quantity: 1, foil_quantity: 0)
    create(:collection_magic_card, collection: collection, magic_card: mox, quantity: 0, foil_quantity: 4)
  end

  # the grouped, owned-price ordered relation the controller hands to pagy
  def grouped(column: nil, direction: nil)
    cards = Search::Collection.call(
      cards: MagicCard.joins(collection_magic_cards: :collection).where(collections: { user_id: user.id }),
      search_term: '', sort_by: :price
    )
    CollectionQuery::CollectionSort.call(cards: cards, column: column, direction: direction)
  end

  it 'returns the page in the order the relation asks for' do
    result = described_class.call(cards: grouped)

    # mox on its foil_price, then bolt, then ritual
    expect(result.map(&:name)).to eq(['Mox Pearl', 'Lightning Bolt', 'Dark Ritual'])
  end

  # the narrow select has to survive every sort the table offers - a sort that leaned on a
  # SELECT alias would lose it when the select list is replaced
  {
    'card_number' => { direction: 'asc', expected: ['Dark Ritual', 'Mox Pearl', 'Lightning Bolt'] },
    'name' => { direction: 'asc', expected: ['Dark Ritual', 'Lightning Bolt', 'Mox Pearl'] },
    'normal_price' => { direction: 'desc', expected: ['Lightning Bolt', 'Dark Ritual', 'Mox Pearl'] }
  }.each do |column, config|
    it "returns the page in order for a #{column} sort" do
      result = described_class.call(cards: grouped(column: column, direction: config[:direction]))

      expect(result.map(&:name)).to eq(config[:expected])
    end
  end

  # the table view gates its price columns on these, so they have to survive the second fetch
  it 'carries the summed quantities the table view reads' do
    result = described_class.call(cards: grouped).index_by(&:name)

    expect(result['Lightning Bolt'].quantity.to_i).to eq(5)
    expect(result['Lightning Bolt'].foil_quantity.to_i).to eq(0)
    expect(result['Mox Pearl'].quantity.to_i).to eq(0)
    expect(result['Mox Pearl'].foil_quantity.to_i).to eq(4)
  end

  it 'returns full magic_cards rows, not just the narrow columns' do
    card = described_class.call(cards: grouped).first

    expect(card.name).to be_present
    expect(card.card_number).to be_present
    expect(card.boxset_id).to eq(boxset.id)
  end

  it 'respects the limit and offset pagy applied' do
    result = described_class.call(cards: grouped.offset(1).limit(1))

    expect(result.map(&:name)).to eq(['Lightning Bolt'])
  end

  it 'preloads the associations it is given' do
    card = described_class.call(cards: grouped, preloads: %i[boxset finishes]).first

    expect(card.association(:boxset)).to be_loaded
    expect(card.association(:finishes)).to be_loaded
  end

  it 'returns an empty array for a page past the end' do
    expect(described_class.call(cards: grouped.offset(50).limit(50))).to eq([])
  end

  # Builder and Filter hang HAVING off the aggregates and no-op without the GROUP BY, so an
  # ungrouped relation is not the collections relation and gets loaded as-is
  it 'loads an ungrouped relation unchanged' do
    result = described_class.call(cards: MagicCard.where(id: bolt.id), preloads: %i[boxset])

    expect(result.map(&:name)).to eq(['Lightning Bolt'])
    expect(result.first.association(:boxset)).to be_loaded
  end
end
