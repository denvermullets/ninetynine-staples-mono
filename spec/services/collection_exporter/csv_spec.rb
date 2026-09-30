require 'rails_helper'

RSpec.describe CollectionExporter::Csv, type: :service do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:binder) { create(:collection, user: user, name: 'Binder', collection_type: 'binder') }
  let(:deck) { create(:collection, user: user, name: 'Atraxa', collection_type: 'commander_deck') }
  let(:boxset) { create(:boxset, code: '2xm') }
  let(:bolt) { create(:magic_card, name: 'Lightning Bolt', boxset: boxset, card_number: '141') }
  let(:bolt_id) { SecureRandom.uuid }

  before { MagicCardIdentifier.create!(magic_card: bolt, scryfall_id: bolt_id) }

  def parse(csv) = CSV.parse(csv, headers: true)

  it 'writes one row per card with a column per finish' do
    create(:collection_magic_card, collection: binder, magic_card: bolt,
                                   quantity: 2, foil_quantity: 1, proxy_quantity: 3, proxy_foil_quantity: 4)

    rows = parse(described_class.call(collections: binder))

    expect(rows.headers).to eq(described_class::HEADERS)
    expect(rows.size).to eq(1)
    expect(rows.first.to_h).to eq(
      'Scryfall ID' => bolt_id, 'Name' => 'Lightning Bolt', 'Edition Code' => '2XM', 'Collector Number' => '141',
      'Quantity' => '2', 'Foil Quantity' => '1', 'Proxy Quantity' => '3', 'Proxy Foil Quantity' => '4'
    )
  end

  it 'sums a card across boards and collections, and names them when asked' do
    create(:collection_magic_card, collection: binder, magic_card: bolt, quantity: 2)
    create(:collection_magic_card, collection: deck, magic_card: bolt, quantity: 1, board_type: 'sideboard')

    rows = parse(described_class.call(collections: user.collections, list_collections: true))

    expect(rows.size).to eq(1)
    expect(rows.first['Quantity']).to eq('3')
    expect(rows.first['Collections']).to eq('Atraxa; Binder')
  end

  it 'leaves out staged and needed rows, and rows with nothing in them' do
    create(:collection_magic_card, collection: deck, magic_card: bolt, quantity: 0, staged: true, staged_quantity: 1)
    create(:collection_magic_card, collection: deck, magic_card: bolt, quantity: 1, needed: true)
    create(:collection_magic_card, collection: binder, magic_card: bolt, quantity: 0)

    rows = parse(described_class.call(collections: user.collections))

    expect(rows.size).to eq(0)
  end

  it 'only exports the collections it was given' do
    other = create(:collection, user: create(:user))
    create(:collection_magic_card, collection: other, magic_card: bolt, quantity: 5)

    expect(parse(described_class.call(collections: binder)).size).to eq(0)
  end

  it 'round-trips through the importer' do
    create(:collection_magic_card, collection: binder, magic_card: bolt,
                                   quantity: 2, foil_quantity: 1, proxy_quantity: 3, proxy_foil_quantity: 4)
    target = create(:collection, user: user, collection_type: 'collection')

    perform_enqueued_jobs do
      CollectionImporter::CsvParser.call(csv_data: described_class.call(collections: binder),
                                         collection: target, user: user)
    end

    card = target.collection_magic_cards.find_by(magic_card: bolt)
    expect(card.attributes.slice('quantity', 'foil_quantity', 'proxy_quantity', 'proxy_foil_quantity'))
      .to eq('quantity' => 2, 'foil_quantity' => 1, 'proxy_quantity' => 3, 'proxy_foil_quantity' => 4)
    expect(target.reload.total_proxy_foil_quantity).to eq(4)
  end
end
