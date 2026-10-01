require 'rails_helper'

RSpec.describe CollectionStats::SetValueHistory, type: :service do
  subject(:result) { described_class.call(collection_ids: [collection.id], boxset: set) }

  let(:collection) { create(:collection) }
  let(:set) { create(:boxset) }

  def card(normal: [], foil: [], **attributes)
    create(:magic_card, boxset: set, price_history: { 'normal' => normal, 'foil' => foil }, **attributes)
  end

  def own(magic_card, **attributes)
    create(:collection_magic_card, { collection: collection, magic_card: magic_card,
                                     quantity: 1 }.merge(attributes))
  end

  it 'prices each finish you hold at that finish on each day' do
    own(card(normal: [{ '2026-01-01' => 1.0 }, { '2026-01-02' => 2.0 }],
             foil: [{ '2026-01-01' => 10.0 }, { '2026-01-02' => 12.0 }]),
        quantity: 2, foil_quantity: 1)

    expect(result).to eq('2026-01-01' => 12.0, '2026-01-02' => 16.0)
  end

  it 'sums every card you hold from the set' do
    own(card(normal: [{ '2026-01-01' => 1.0 }]))
    own(card(normal: [{ '2026-01-01' => 2.5 }]))

    expect(result).to eq('2026-01-01' => 3.5)
  end

  it 'carries a price across a day missing from one card' do
    own(card(normal: [{ '2026-01-01' => 1.0 }, { '2026-01-02' => 1.0 }, { '2026-01-03' => 1.0 }]))
    own(card(normal: [{ '2026-01-01' => 5.0 }, { '2026-01-03' => 6.0 }]))

    expect(result).to eq('2026-01-01' => 6.0, '2026-01-02' => 6.0, '2026-01-03' => 7.0)
  end

  it 'leaves out proxies, cards from other sets and cards nobody holds' do
    own(card(normal: [{ '2026-01-01' => 1.0 }]))
    own(card(normal: [{ '2026-01-01' => 50.0 }]), quantity: 0, proxy_quantity: 1)
    card(normal: [{ '2026-01-01' => 100.0 }])
    own(create(:magic_card, price_history: { 'normal' => [{ '2026-01-01' => 200.0 }] }))

    expect(result).to eq('2026-01-01' => 1.0)
  end

  it 'leaves out staged and wishlist rows' do
    own(card(normal: [{ '2026-01-01' => 1.0 }]))
    own(card(normal: [{ '2026-01-01' => 50.0 }]), staged: true)
    own(card(normal: [{ '2026-01-01' => 70.0 }]), needed: true)

    expect(result).to eq('2026-01-01' => 1.0)
  end

  it 'is empty when nothing you hold has a price history' do
    own(create(:magic_card, boxset: set, price_history: nil))

    expect(result).to eq({})
  end

  it 'is empty with no collections to measure' do
    expect(described_class.call(collection_ids: [], boxset: set)).to eq({})
  end
end
