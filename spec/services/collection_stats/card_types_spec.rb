require 'rails_helper'

RSpec.describe CollectionStats::CardTypes, type: :service do
  subject(:result) { described_class.call(collection_ids: [collection.id]) }

  let(:collection) { create(:collection) }

  def add(*type_names, quantity: 1, price: 10, commander: false)
    card = create(:magic_card, normal_price: price, can_be_commander: commander)
    type_names.each do |name|
      MagicCardType.create!(magic_card: card, card_type: CardType.find_or_create_by!(name: name))
    end
    create(:collection_magic_card, collection: collection, magic_card: card, quantity: quantity)
    card
  end

  def row(label)
    result[:types].find { |type| type[:label] == label }
  end

  describe 'multi-type cards' do
    it 'counts an Artifact Creature under both types' do
      add('Artifact', 'Creature', quantity: 2)

      expect(row('Creature')[:copies]).to eq(2)
      expect(row('Artifact')[:copies]).to eq(2)
    end

    it 'counts its value under both types too' do
      add('Artifact', 'Creature', quantity: 1, price: 30)

      expect(row('Creature')[:value]).to eq(30)
      expect(row('Artifact')[:value]).to eq(30)
    end

    # shares are a share of type slots, not of cards - that keeps the bars filling the panel
    # rather than overflowing it, at the cost of copies and value being the double-counted numbers
    it 'still splits shares across a total of 100%' do
      add('Artifact', 'Creature', quantity: 1, price: 30)

      expect(result[:types].sum { |type| type[:share] }).to eq(100.0)
    end
  end

  describe 'ordering and labelling' do
    it 'follows the deck builder type order' do
      add('Land')
      add('Creature')
      add('Instant')

      expect(result[:types].map { |type| type[:label] }).to eq(%w[Creature Instant Land])
    end

    it 'reuses the deck builder constant rather than redefining it' do
      expect(described_class::ORDER).to be(DeckBuilder::GroupCards::TYPE_ORDER)
    end

    # card_types carries a long tail of un-set oddities that would otherwise crowd the panel
    it 'folds unrecognised types into Other' do
      add('Eaturecray', quantity: 2)
      add('Phenomenon', quantity: 3)

      expect(result[:types].map { |type| type[:label] }).to eq(['Other'])
      expect(row('Other')[:copies]).to eq(5)
    end

    it 'keeps Other last' do
      add('Creature')
      add('Scheme')

      expect(result[:types].last[:label]).to eq('Other')
    end
  end

  describe 'possible commanders' do
    it 'counts printings flagged as able to lead a deck' do
      add('Creature', commander: true)
      add('Creature', commander: true)
      add('Creature', commander: false)

      expect(result[:possible_commanders]).to eq(2)
    end

    # it is a flag on magic_cards, not a card type, so it must not appear as a type row
    it 'keeps them out of the type rows' do
      add('Creature', commander: true)

      expect(result[:types].map { |type| type[:label] }).to eq(['Creature'])
    end

    it 'ignores commanders sitting in staged rows' do
      card = create(:magic_card, can_be_commander: true)
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 1, staged: true)

      expect(result[:possible_commanders]).to eq(0)
    end
  end

  it 'returns empty results and runs no queries when there are no collections' do
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
    end
    empty = described_class.call(collection_ids: [])
    ActiveSupport::Notifications.unsubscribe(subscriber)

    expect(empty).to eq({ types: [], possible_commanders: 0 })
    expect(queries).to be_empty
  end
end
