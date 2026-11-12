require 'rails_helper'

RSpec.describe MagicCardHelper, type: :helper do
  describe '#reserved_tint_class' do
    it 'tints a card on the Reserved List' do
      expect(helper.reserved_tint_class(build(:magic_card, is_reserved: true))).to include('from-ink-gold-accent')
    end

    it 'leaves every other card alone' do
      expect(helper.reserved_tint_class(build(:magic_card, is_reserved: false))).to be_nil
    end
  end

  describe '#add_to_collection_option_data' do
    let(:collection) { create(:collection) }
    let(:magic_card) { create(:magic_card) }

    it 'reports the copies of this printing the collection holds' do
      location = create(:collection_magic_card, collection:, magic_card:, card_uuid: magic_card.card_uuid,
                                                quantity: 2, foil_quantity: 1, proxy_quantity: 3)

      expect(helper.add_to_collection_option_data(collection, magic_card, [location]))
        .to eq(regular_qty: 2, foil_qty: 1, proxy_qty: 3, proxy_foil_qty: 0)
    end

    it 'reports zeros for a collection without the card' do
      other = create(:collection_magic_card, magic_card:, card_uuid: magic_card.card_uuid, quantity: 4)

      expect(helper.add_to_collection_option_data(collection, magic_card, [other]).values).to all(eq(0))
    end
  end
end
