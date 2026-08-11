require 'rails_helper'

RSpec.describe CollectionStats::Colors, type: :service do
  subject(:rows) { described_class.call(collection_ids: [collection.id]) }

  let(:collection) { create(:collection) }

  def add(*letters, quantity: 1, price: 10)
    card = create(:magic_card, normal_price: price)
    letters.each do |letter|
      MagicCardColorIdent.create!(magic_card: card, color: Color.find_or_create_by!(name: letter))
    end
    create(:collection_magic_card, collection: collection, magic_card: card, quantity: quantity)
    card
  end

  def row(label)
    rows.find { |bucket| bucket[:label] == label }
  end

  describe 'bucketing' do
    # the whole justification for rolling the join table up before grouping it: a Golgari card
    # has two magic_card_color_idents rows, and a naive group would bill its $30 twice
    it 'counts a two-colour card once, under Multicolor' do
      add('B', 'G', quantity: 1, price: 30)

      expect(row('Multicolor')[:copies]).to eq(1)
      expect(row('Multicolor')[:value]).to eq(30)
      expect(rows.sum { |bucket| bucket[:copies] }).to eq(1)
      expect(rows.map { |bucket| bucket[:label] }).to eq(['Multicolor'])
    end

    it 'treats a three-colour card as Multicolor too' do
      add('W', 'U', 'B')

      expect(row('Multicolor')[:copies]).to eq(1)
    end

    # the LEFT JOIN regression: an inner join drops these cards entirely and the totals stop
    # reconciling with the rest of the dashboard
    it 'buckets a card with no colour identity rows as Colorless' do
      add(quantity: 3, price: 5)

      expect(row('Colorless')[:copies]).to eq(3)
      expect(row('Colorless')[:value]).to eq(15)
    end

    it 'names single letters after the colours they stand for' do
      %w[W U B R G].each { |letter| add(letter) }

      expect(rows.map { |bucket| bucket[:label] }).to eq(%w[White Blue Black Red Green])
    end

    it 'leaves out buckets nothing landed in' do
      add('W')

      expect(rows.map { |bucket| bucket[:label] }).to eq(['White'])
    end
  end

  describe 'ordering' do
    it 'runs White through Multicolor regardless of insertion order' do
      add('G')
      add('B', 'R')
      add('B')
      add('W')
      add

      expect(rows.map { |bucket| bucket[:label] })
        .to eq(%w[White Black Green Colorless Multicolor])
    end

    # reuse, so this panel and the collection page's colour grouping cannot disagree
    it 'takes its order from the collection page grouping' do
      expect(described_class::ORDER).to be(Collections::GroupCards::COLOR_ORDER)
    end
  end

  describe 'figures' do
    it 'counts every finish, not just non-foil copies' do
      card = create(:magic_card, normal_price: 1, foil_price: 2)
      MagicCardColorIdent.create!(magic_card: card, color: Color.find_or_create_by!(name: 'R'))
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 1, foil_quantity: 1,
                                     proxy_quantity: 1, proxy_foil_quantity: 1)

      expect(row('Red')[:copies]).to eq(4)
      expect(row('Red')[:value]).to eq(6)
    end

    it 'gives each colour its share of total copies' do
      add('W', quantity: 3)
      add('U', quantity: 1)

      expect(rows.map { |bucket| bucket[:share] }).to eq([75.0, 25.0])
    end

    it 'carries a mana glyph for every colour the font has one for' do
      %w[W U B R G].each { |letter| add(letter) }
      add

      expect(rows.map { |bucket| bucket[:swatch] })
        .to eq(%w[ms-w ms-u ms-b ms-r ms-g ms-c])
    end

    # mana-font ships no multicolour symbol, so the legend leans on its colour swatch alone
    it 'leaves Multicolor without a glyph' do
      add('W', 'U')

      expect(row('Multicolor')[:swatch]).to be_nil
    end

    it 'excludes staged and wishlist rows' do
      card = create(:magic_card, normal_price: 5)
      MagicCardColorIdent.create!(magic_card: card, color: Color.find_or_create_by!(name: 'G'))
      create(:collection_magic_card, collection: collection, magic_card: card,
                                     quantity: 4, staged: true)

      expect(rows).to be_empty
    end
  end

  it 'returns nothing and runs no queries when there are no collections' do
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
    end
    result = described_class.call(collection_ids: [])
    ActiveSupport::Notifications.unsubscribe(subscriber)

    expect(result).to eq([])
    expect(queries).to be_empty
  end
end
