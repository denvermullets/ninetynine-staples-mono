require 'rails_helper'

RSpec.describe CollectionQuery::ColumnSort, type: :service do
  let!(:card_a) { create(:magic_card, name: 'Alpha', mana_value: 3, edhrec_rank: 100) }
  let!(:card_b) { create(:magic_card, name: 'Beta', mana_value: 1, edhrec_rank: nil) }
  let!(:card_c) { create(:magic_card, name: 'Gamma', mana_value: 5, edhrec_rank: 50) }

  let(:records) { MagicCard.where(id: [card_a.id, card_b.id, card_c.id]) }

  context 'sorting by name ASC' do
    it 'sorts alphabetically' do
      result = described_class.call(records: records, column: 'name', direction: 'asc')
      expect(result.map(&:name)).to eq(%w[Alpha Beta Gamma])
    end
  end

  context 'sorting by name DESC' do
    it 'sorts reverse alphabetically' do
      result = described_class.call(records: records, column: 'name', direction: 'desc')
      expect(result.map(&:name)).to eq(%w[Gamma Beta Alpha])
    end
  end

  context 'sorting numeric column DESC with NULLS LAST' do
    it 'places nulls at the end' do
      result = described_class.call(records: records, column: 'edhrec_rank', direction: 'desc')
      expect(result.last.name).to eq('Beta')
    end
  end

  context 'sorting by buylist price' do
    let!(:card_a) { create(:magic_card, name: 'Alpha', ck_buylist_normal_price: 3.0, ck_buylist_foil_price: nil) }
    let!(:card_b) { create(:magic_card, name: 'Beta', ck_buylist_normal_price: nil, ck_buylist_foil_price: 9.0) }
    let!(:card_c) { create(:magic_card, name: 'Gamma', ck_buylist_normal_price: 7.0, ck_buylist_foil_price: 2.0) }

    it 'sorts by the regular buylist price with nulls last on desc' do
      result = described_class.call(records: records, column: 'ck_buylist_normal_price', direction: 'desc')
      expect(result.map(&:name)).to eq(%w[Gamma Alpha Beta])
    end

    it 'sorts by the foil buylist price with nulls last on desc' do
      result = described_class.call(records: records, column: 'ck_buylist_foil_price', direction: 'desc')
      expect(result.map(&:name)).to eq(%w[Beta Gamma Alpha])
    end
  end

  context 'with invalid column' do
    it 'returns records unmodified' do
      result = described_class.call(records: records, column: 'invalid')
      expect(result.count).to eq(3)
    end
  end

  context 'with table_name' do
    it 'qualifies the sort column with table name' do
      result = described_class.call(
        records: records, column: 'name', direction: 'asc', table_name: 'magic_cards'
      )
      expect(result.map(&:name)).to eq(%w[Alpha Beta Gamma])
    end
  end

  context 'backwards compatible cards: parameter' do
    it 'accepts cards keyword' do
      result = described_class.call(cards: records, column: 'name', direction: 'asc')
      expect(result.map(&:name)).to eq(%w[Alpha Beta Gamma])
    end
  end
end
