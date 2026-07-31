require 'rails_helper'

RSpec.describe ResetCollectionValues, type: :job do
  let(:collection) { create(:collection) }

  it 'recalculates the totals from the cards it holds' do
    card = create(:magic_card, normal_price: 5.0, foil_price: 10.0)
    create(:collection_magic_card, collection: collection, magic_card: card, quantity: 2, foil_quantity: 3)

    described_class.perform_now

    expect(collection.reload).to have_attributes(
      total_value: 40, total_quantity: 2, total_foil_quantity: 3
    )
  end

  it 'treats a null price as zero rather than raising' do
    # ~3% of magic_cards carry a null normal_price, which used to blow up the whole run
    priceless = create(:magic_card, normal_price: nil, foil_price: 10.0)
    create(:collection_magic_card, collection: collection, magic_card: priceless, quantity: 4, foil_quantity: 1)

    expect { described_class.perform_now }.not_to raise_error
    expect(collection.reload.total_value).to eq(10)
  end
end
