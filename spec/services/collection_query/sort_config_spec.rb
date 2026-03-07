require 'rails_helper'

RSpec.describe CollectionQuery::SortConfig, type: :service do
  let(:allowed_columns) { %w[name price mana_value] }

  context 'with valid params' do
    let(:config) do
      described_class.new(
        params: { sort: 'price', direction: 'desc' },
        allowed_columns: allowed_columns
      )
    end

    it 'sets column from params' do
      expect(config.column).to eq('price')
    end

    it 'sets direction from params' do
      expect(config.direction).to eq('desc')
    end
  end

  context 'with invalid column' do
    let(:config) do
      described_class.new(
        params: { sort: 'invalid', direction: 'asc' },
        allowed_columns: allowed_columns
      )
    end

    it 'defaults to first allowed column' do
      expect(config.column).to eq('name')
    end
  end

  context 'with invalid direction' do
    let(:config) do
      described_class.new(
        params: { sort: 'name', direction: 'invalid' },
        allowed_columns: allowed_columns
      )
    end

    it 'defaults to asc' do
      expect(config.direction).to eq('asc')
    end
  end

  describe '#link_params' do
    let(:config) do
      described_class.new(
        params: { sort: 'name', direction: 'asc' },
        allowed_columns: allowed_columns
      )
    end

    it 'toggles direction for current column' do
      params = config.link_params('name')
      expect(params[:direction]).to eq('desc')
    end

    it 'defaults to asc for different column' do
      params = config.link_params('price')
      expect(params[:direction]).to eq('asc')
    end
  end

  describe '#sorting?' do
    let(:config) do
      described_class.new(
        params: { sort: 'name', direction: 'asc' },
        allowed_columns: allowed_columns
      )
    end

    it 'returns true for current column' do
      expect(config.sorting?('name')).to be true
    end

    it 'returns false for other columns' do
      expect(config.sorting?('price')).to be false
    end
  end

  describe '#indicator' do
    it 'returns up arrow for ASC' do
      config = described_class.new(
        params: { sort: 'name', direction: 'asc' },
        allowed_columns: allowed_columns
      )
      expect(config.indicator('name')).to eq('▲')
    end

    it 'returns down arrow for DESC' do
      config = described_class.new(
        params: { sort: 'name', direction: 'desc' },
        allowed_columns: allowed_columns
      )
      expect(config.indicator('name')).to eq('▼')
    end

    it 'returns nil for non-sorted column' do
      config = described_class.new(
        params: { sort: 'name', direction: 'asc' },
        allowed_columns: allowed_columns
      )
      expect(config.indicator('price')).to be_nil
    end
  end

  describe 'preserve_params' do
    let(:config) do
      described_class.new(
        params: { sort: 'name', direction: 'asc', search: 'bolt', page: '2' },
        allowed_columns: allowed_columns,
        preserve_params: %i[search page]
      )
    end

    it 'includes preserved params in link_params' do
      params = config.link_params('name')
      expect(params[:search]).to eq('bolt')
      expect(params[:page]).to eq('2')
    end
  end
end
