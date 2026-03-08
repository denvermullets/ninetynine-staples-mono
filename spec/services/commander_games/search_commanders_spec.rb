require 'rails_helper'

RSpec.describe CommanderGames::SearchCommanders, type: :service do
  let!(:commander_card) do
    create(:magic_card, name: 'Atraxa, Praetors Voice', can_be_commander: true)
  end
  let!(:non_commander) do
    create(:magic_card, name: 'Atraxa Skirmisher', can_be_commander: false)
  end

  context 'with a matching query' do
    it 'returns only commander-eligible cards' do
      result = described_class.call(query: 'Atraxa')
      expect(result.map(&:name)).to include('Atraxa, Praetors Voice')
      expect(result.map(&:name)).not_to include('Atraxa Skirmisher')
    end
  end

  context 'with query too short' do
    it 'returns empty' do
      result = described_class.call(query: 'A')
      expect(result).to eq([])
    end
  end

  context 'with no match' do
    it 'returns empty' do
      result = described_class.call(query: 'Nonexistent Card Name')
      expect(result).to be_empty
    end
  end

  context 'deduplicates by name' do
    let!(:commander_reprint) do
      create(:magic_card, name: 'Atraxa, Praetors Voice', can_be_commander: true)
    end

    it 'returns only one version per name' do
      result = described_class.call(query: 'Atraxa, Praetors')
      names = result.map(&:name)
      expect(names.count('Atraxa, Praetors Voice')).to eq(1)
    end
  end
end
