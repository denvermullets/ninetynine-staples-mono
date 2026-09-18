require 'rails_helper'

RSpec.describe WantListHelper, type: :helper do
  describe '#want_filled?' do
    def item(quantity:, owned: nil)
      want = build(:want_list_item, quantity: quantity)
      want.define_singleton_method(:owned_quantity) { owned } unless owned.nil?
      want
    end

    it 'is true once the copies owned cover the quantity wanted' do
      expect(helper.want_filled?(item(quantity: 2, owned: 2))).to be(true)
    end

    it 'is false while the copies owned fall short' do
      expect(helper.want_filled?(item(quantity: 2, owned: 1))).to be(false)
    end

    it 'is false for a row that was not loaded with an owned count' do
      expect(helper.want_filled?(item(quantity: 1))).to be(false)
    end
  end
end
