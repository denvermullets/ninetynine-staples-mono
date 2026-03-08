require 'rails_helper'

RSpec.describe CollectionRecord::UpdateTotals, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user, total_quantity: 5, total_foil_quantity: 2, total_value: 40.0) }

  subject do
    described_class.call(
      collection: collection,
      changes: changes
    )
  end

  context 'when incrementing totals' do
    let(:changes) do
      { quantity: 3, foil_quantity: 1, real_price: 25.0 }
    end

    it 'increments total_quantity' do
      subject
      collection.reload
      expect(collection.total_quantity).to eq(8)
    end

    it 'increments total_foil_quantity' do
      subject
      collection.reload
      expect(collection.total_foil_quantity).to eq(3)
    end

    it 'increments total_value' do
      subject
      collection.reload
      expect(collection.total_value).to eq(65.0)
    end
  end

  context 'when decrementing totals' do
    let(:changes) do
      { quantity: -2, foil_quantity: -1, real_price: -20.0 }
    end

    it 'decrements totals' do
      subject
      collection.reload
      expect(collection.total_quantity).to eq(3)
      expect(collection.total_foil_quantity).to eq(1)
      expect(collection.total_value).to eq(20.0)
    end
  end

  context 'when updating proxy totals' do
    let(:changes) do
      { proxy_quantity: 2, proxy_foil_quantity: 1, proxy_price: 15.0 }
    end

    it 'increments proxy totals' do
      subject
      collection.reload
      expect(collection.total_proxy_quantity).to eq(2)
      expect(collection.total_proxy_foil_quantity).to eq(1)
      expect(collection.proxy_total_value).to eq(15.0)
    end
  end

  context 'with missing change keys' do
    let(:changes) { { quantity: 1 } }

    it 'defaults missing values to zero' do
      subject
      collection.reload
      expect(collection.total_quantity).to eq(6)
      expect(collection.total_foil_quantity).to eq(2)
    end
  end
end
