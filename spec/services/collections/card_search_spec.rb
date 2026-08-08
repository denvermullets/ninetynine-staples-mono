require 'rails_helper'

RSpec.describe Collections::CardSearch, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }

  let!(:goblin) do
    typed(create(:magic_card, name: 'Goblin Guide', card_type: 'Creature - Goblin', rarity: 'rare', mana_value: 1),
          'Creature', sub_type: 'Goblin')
  end
  let!(:ritual) do
    typed(create(:magic_card, name: 'Dark Ritual', card_type: 'Instant', rarity: 'common', mana_value: 1), 'Instant')
  end

  def typed(card, type, sub_type: nil)
    MagicCardType.create!(magic_card: card, card_type: CardType.find_or_create_by!(name: type))
    MagicCardSubType.create!(magic_card: card, sub_type: SubType.find_or_create_by!(name: sub_type)) if sub_type
    card
  end

  before do
    create(:collection_magic_card, collection: collection, magic_card: goblin, quantity: 1)
    create(:collection_magic_card, collection: collection, magic_card: ritual, quantity: 1)

    MagicCardColor.create!(magic_card: goblin, color: Color.find_or_create_by!(name: 'R'))
    MagicCardColor.create!(magic_card: ritual, color: Color.find_or_create_by!(name: 'B'))
  end

  # the same SortConfig the CollectionSorting concern hands the service from the controller
  def sort_config(params)
    CollectionQuery::SortConfig.new(
      params: params,
      allowed_columns: CollectionSorting::SORT_COLUMNS,
      default_column: CollectionQuery::CollectionSort::DEFAULT_COLUMN
    )
  end

  def search(query, extra = {})
    params = { search: query, collection_id: collection.id }.merge(extra)
    described_class.call(user: user, params: params, sort_config: sort_config(params))
  end

  def names(query, extra = {})
    search(query, extra)[:cards].map(&:name)
  end

  it 'narrows to cards matching an advanced query' do
    expect(names('c:r t:creature r:rare')).to contain_exactly('Goblin Guide')
  end

  it 'combines free text with terms' do
    expect(names('ritual t:instant')).to contain_exactly('Dark Ritual')
  end

  it 'still treats a plain string as a name search' do
    expect(names('goblin')).to contain_exactly('Goblin Guide')
  end

  it 'returns everything when the query is blank' do
    expect(names('')).to contain_exactly('Goblin Guide', 'Dark Ritual')
  end

  it 'does not blow up on a query with an unusable value' do
    expect { names('mv>=banana') }.not_to raise_error
  end

  it 'does not leak another users cards' do
    stranger_card = typed(create(:magic_card, name: 'Goblin Lackey'), 'Creature', sub_type: 'Goblin')
    create(:collection_magic_card, collection: create(:collection), magic_card: stranger_card, quantity: 1)

    expect(names('goblin t:creature', collection_id: nil)).to contain_exactly('Goblin Guide')
  end

  it 'exposes the parsed query alongside the cards' do
    result = search('goblin t:creature')

    expect(result[:card_query].free_text).to eq('goblin')
    expect(result[:card_query].terms.map(&:key)).to eq(['t'])
  end

  # Builder and Filter both hang HAVING clauses off the aggregates Search::Collection selects,
  # so the relation has to come back grouped or those filters silently stop applying
  it 'returns a grouped relation carrying the quantity aggregates' do
    result = search('')[:cards]

    expect(result.group_values).to be_present
    expect(result.map { |card| card.quantity.to_i }).to all(eq(1))
  end

  it 'applies the requested column sort' do
    expect(names('', sort: 'name', direction: 'asc')).to eq(['Dark Ritual', 'Goblin Guide'])
    expect(names('', sort: 'name', direction: 'desc')).to eq(['Goblin Guide', 'Dark Ritual'])
  end
end
