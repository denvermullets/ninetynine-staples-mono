require 'rails_helper'

RSpec.describe CollectionReservedHelper, type: :helper do
  describe '#sort_params' do
    it 'flips the direction of the sort already in force' do
      expect(helper.sort_params('price', 'price', 'desc')).to eq(sort: 'price', direction: 'asc')
      expect(helper.sort_params('price', 'price', 'asc')).to eq(sort: 'price', direction: 'desc')
    end

    it 'drops the direction when switching sorts so the new one opens its default way' do
      expect(helper.sort_params('price', 'name', 'asc')).to eq(sort: 'price', direction: nil)
    end
  end
end
