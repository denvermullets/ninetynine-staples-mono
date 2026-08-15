require 'rails_helper'

RSpec.describe CollectionStats::BuildableTribes, type: :service do
  subject(:tribes) { described_class.call(collection_ids: [collection.id], subtypes: %w[Goblin Elf]) }

  let(:user) { create(:user, username: 'brewer') }
  let(:collection) { create(:collection, user: user) }

  def bits(*letters)
    letters.sum { |letter| Commanders::ColorMask::BITS.fetch(letter) }
  end

  def color(letter)
    @colors ||= {}
    @colors[letter] ||= Color.find_by(name: letter) || create(:color, name: letter)
  end

  def own(sub_type:, colors: [], name: 'Creature', oracle_id: SecureRandom.uuid, staged: false)
    card = create(:magic_card, name: name, scryfall_oracle_id: oracle_id,
                               card_type: 'Creature - Thing')
    colors.each { |letter| MagicCardColorIdent.create!(magic_card: card, color: color(letter)) }
    MagicCardSubType.create!(magic_card: card, sub_type: SubType.find_or_create_by!(name: sub_type))
    create(:collection_magic_card, collection: collection, magic_card: card, staged: staged)
    card
  end

  it 'counts an owned creature under its colour identity' do
    own(sub_type: 'Goblin', colors: ['R'])

    expect(tribes[bits('R')]).to eq({ 'Goblin' => 1 })
  end

  # Same bucketing rule as BuildableProfile: a mono-red Goblin lord must not be credited with your
  # Jund goblins.
  it 'keeps a two-coloured creature out of the mono-coloured bucket' do
    own(sub_type: 'Goblin', colors: %w[B R])

    expect(tribes[bits('R')]).to be_nil
  end

  it 'counts a creature once however many printings are owned' do
    oracle_id = SecureRandom.uuid
    own(sub_type: 'Goblin', colors: ['R'], oracle_id: oracle_id, name: 'Krenko')
    own(sub_type: 'Goblin', colors: ['R'], oracle_id: oracle_id, name: 'Krenko')

    expect(tribes[bits('R')]).to eq({ 'Goblin' => 1 })
  end

  it 'leaves out a creature type nobody asked about' do
    own(sub_type: 'Zombie', colors: ['B'])

    expect(tribes).to be_empty
  end

  it 'leaves out a card staged into a deck build' do
    own(sub_type: 'Goblin', colors: ['R'], staged: true)

    expect(tribes).to be_empty
  end

  # Discovery only asks for the types its candidates actually name, so the no-themes case is the
  # common one and must not turn into a query for all 377.
  it 'asks nothing of the database when no commander named a type' do
    own(sub_type: 'Goblin', colors: ['R'])

    expect(described_class.call(collection_ids: [collection.id], subtypes: [])).to eq({})
  end
end
