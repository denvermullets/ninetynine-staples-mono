require 'rails_helper'

RSpec.describe Collections::UpdateTotals, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let(:magic_card_a) { create(:magic_card, normal_price: 5.0, foil_price: 10.0) }
  let(:magic_card_b) { create(:magic_card, normal_price: 3.0, foil_price: 6.0) }

  subject { described_class.call(collection: collection) }

  context 'with finalized owned cards' do
    before do
      create(:collection_magic_card,
             collection: collection,
             magic_card: magic_card_a,
             quantity: 3,
             foil_quantity: 1,
             proxy_quantity: 2,
             proxy_foil_quantity: 1,
             staged: false,
             needed: false)

      create(:collection_magic_card,
             collection: collection,
             magic_card: magic_card_b,
             quantity: 2,
             foil_quantity: 0,
             proxy_quantity: 0,
             proxy_foil_quantity: 0,
             staged: false,
             needed: false)
    end

    it 'calculates total_quantity' do
      subject
      collection.reload
      expect(collection.total_quantity).to eq(5) # 3 + 2
    end

    it 'calculates total_foil_quantity' do
      subject
      collection.reload
      expect(collection.total_foil_quantity).to eq(1)
    end

    it 'calculates total_value' do
      subject
      collection.reload
      expected = (3 * 5.0) + (1 * 10.0) + (2 * 3.0) + (0 * 6.0)
      expect(collection.total_value).to eq(expected)
    end

    it 'calculates proxy totals' do
      subject
      collection.reload
      expect(collection.total_proxy_quantity).to eq(2)
      expect(collection.total_proxy_foil_quantity).to eq(1)
    end

    it 'calculates proxy value' do
      subject
      collection.reload
      expected_proxy = (2 * 5.0) + (1 * 10.0)
      expect(collection.proxy_total_value).to eq(expected_proxy)
    end
  end

  context 'with staged cards (should be excluded)' do
    before do
      create(:collection_magic_card,
             collection: collection,
             magic_card: magic_card_a,
             staged: true,
             staged_quantity: 5,
             quantity: 0,
             foil_quantity: 0)
    end

    it 'does not count staged cards in totals' do
      subject
      collection.reload
      expect(collection.total_quantity).to eq(0)
    end
  end

  context 'with needed cards (should be excluded)' do
    before do
      create(:collection_magic_card,
             collection: collection,
             magic_card: magic_card_a,
             needed: true,
             staged: false,
             quantity: 2,
             foil_quantity: 0)
    end

    it 'does not count needed cards in totals' do
      subject
      collection.reload
      expect(collection.total_quantity).to eq(0)
    end
  end

  context 'with no cards' do
    it 'sets all totals to zero' do
      subject
      collection.reload
      expect(collection.total_quantity).to eq(0)
      expect(collection.total_foil_quantity).to eq(0)
      expect(collection.total_value).to eq(0)
    end
  end
end
