require 'rails_helper'

RSpec.describe CollectionMagicCard, type: :model do
  describe 'validations' do
    %i[quantity foil_quantity proxy_quantity proxy_foil_quantity
       staged_quantity staged_foil_quantity staged_proxy_quantity staged_proxy_foil_quantity].each do |field|
      it "rejects negative #{field}" do
        card = build(:collection_magic_card, field => -1)
        expect(card).not_to be_valid
        expect(card.errors[field]).to be_present
      end
    end

    it 'allows nil board_type' do
      card = build(:collection_magic_card, board_type: nil)
      expect(card).to be_valid
    end

    it 'allows valid board_type values' do
      %w[mainboard sideboard commander].each do |bt|
        card = build(:collection_magic_card, board_type: bt)
        expect(card).to be_valid
      end
    end

    it 'rejects invalid board_type values' do
      card = build(:collection_magic_card, board_type: 'invalid')
      expect(card).not_to be_valid
      expect(card.errors[:board_type]).to be_present
    end
  end

  describe 'scopes' do
    describe '.commanders' do
      it 'returns cards with board_type commander' do
        commander = create(:collection_magic_card, board_type: 'commander')
        create(:collection_magic_card, board_type: 'mainboard')
        expect(described_class.commanders).to eq([commander])
      end
    end

    describe '.staged' do
      it 'returns cards where staged is true' do
        staged = create(:collection_magic_card, staged: true)
        create(:collection_magic_card, staged: false)
        expect(described_class.staged).to eq([staged])
      end
    end

    describe '.finalized' do
      it 'returns cards where staged is false' do
        create(:collection_magic_card, staged: true)
        finalized = create(:collection_magic_card, staged: false)
        expect(described_class.finalized).to eq([finalized])
      end
    end

    describe '.needed' do
      it 'returns cards where needed is true' do
        needed = create(:collection_magic_card, needed: true)
        create(:collection_magic_card, needed: false)
        expect(described_class.needed).to eq([needed])
      end
    end

    describe '.owned' do
      it 'returns cards where needed is false' do
        create(:collection_magic_card, needed: true)
        owned = create(:collection_magic_card, needed: false)
        expect(described_class.owned).to eq([owned])
      end
    end

    describe '.from_collection' do
      it 'returns cards with a source_collection_id' do
        source = create(:collection)
        from_collection = create(:collection_magic_card, source_collection: source)
        create(:collection_magic_card, source_collection: nil)
        expect(described_class.from_collection).to eq([from_collection])
      end
    end

    describe '.planned' do
      it 'returns staged cards without a source_collection_id' do
        planned = create(:collection_magic_card, staged: true, source_collection: nil)
        create(:collection_magic_card, staged: true, source_collection: create(:collection))
        create(:collection_magic_card, staged: false, source_collection: nil)
        expect(described_class.planned).to eq([planned])
      end
    end
  end

  describe '#total_regular' do
    it 'sums quantity and proxy_quantity' do
      card = build(:collection_magic_card, quantity: 3, proxy_quantity: 2)
      expect(card.total_regular).to eq(5)
    end
  end

  describe '#total_foil' do
    it 'sums foil_quantity and proxy_foil_quantity' do
      card = build(:collection_magic_card, foil_quantity: 1, proxy_foil_quantity: 4)
      expect(card.total_foil).to eq(5)
    end
  end

  describe '#display_foil?' do
    context 'when not staged' do
      it 'returns true when foil_quantity is positive' do
        card = build(:collection_magic_card, staged: false, foil_quantity: 1, proxy_foil_quantity: 0)
        expect(card.display_foil?).to be true
      end

      it 'returns true when proxy_foil_quantity is positive' do
        card = build(:collection_magic_card, staged: false, foil_quantity: 0, proxy_foil_quantity: 1)
        expect(card.display_foil?).to be true
      end

      it 'returns false when both are zero' do
        card = build(:collection_magic_card, staged: false, foil_quantity: 0, proxy_foil_quantity: 0)
        expect(card.display_foil?).to be false
      end
    end

    context 'when staged' do
      it 'returns true when staged_foil_quantity is positive' do
        card = build(:collection_magic_card, staged: true, staged_foil_quantity: 1, staged_proxy_foil_quantity: 0)
        expect(card.display_foil?).to be true
      end

      it 'returns true when staged_proxy_foil_quantity is positive' do
        card = build(:collection_magic_card, staged: true, staged_foil_quantity: 0, staged_proxy_foil_quantity: 2)
        expect(card.display_foil?).to be true
      end

      it 'returns false when both staged foil quantities are zero' do
        card = build(:collection_magic_card, staged: true, staged_foil_quantity: 0, staged_proxy_foil_quantity: 0)
        expect(card.display_foil?).to be false
      end
    end
  end

  describe '#display_proxy?' do
    context 'when not staged' do
      it 'returns true when proxy_quantity is positive' do
        card = build(:collection_magic_card, staged: false, proxy_quantity: 1, proxy_foil_quantity: 0)
        expect(card.display_proxy?).to be true
      end

      it 'returns false when both are zero' do
        card = build(:collection_magic_card, staged: false, proxy_quantity: 0, proxy_foil_quantity: 0)
        expect(card.display_proxy?).to be false
      end
    end

    context 'when staged' do
      it 'returns true when staged_proxy_quantity is positive' do
        card = build(:collection_magic_card, staged: true, staged_proxy_quantity: 3, staged_proxy_foil_quantity: 0)
        expect(card.display_proxy?).to be true
      end

      it 'returns false when both staged proxy quantities are zero' do
        card = build(:collection_magic_card, staged: true, staged_proxy_quantity: 0, staged_proxy_foil_quantity: 0)
        expect(card.display_proxy?).to be false
      end
    end
  end

  describe '#real_value' do
    it 'calculates value from real quantities and card prices' do
      card = create(:collection_magic_card, quantity: 2, foil_quantity: 1)
      expect(card.real_value).to eq((2 * 5.0) + (1 * 10.0))
    end
  end

  describe '#proxy_value' do
    it 'calculates value from proxy quantities and card prices' do
      card = create(:collection_magic_card, proxy_quantity: 3, proxy_foil_quantity: 2)
      expect(card.proxy_value).to eq((3 * 5.0) + (2 * 10.0))
    end
  end

  describe '#display_value' do
    it 'returns display_quantity * display_price for non-staged cards' do
      card = create(:collection_magic_card, quantity: 2, foil_quantity: 1, proxy_quantity: 1, proxy_foil_quantity: 1)
      expect(card.display_value).to eq(5 * 5.0)
    end

    context 'when card is staged' do
      it 'uses staged display_quantity * display_price' do
        card = create(:collection_magic_card,
                      staged: true,
                      staged_quantity: 2, staged_foil_quantity: 1,
                      staged_proxy_quantity: 1, staged_proxy_foil_quantity: 1)
        expect(card.display_value).to eq(5 * 5.0)
      end
    end

    context 'when card is foil-only (normal_price is 0)' do
      it 'uses foil_price as display_price' do
        magic_card = create(:magic_card, normal_price: 0.0, foil_price: 15.0)
        card = create(:collection_magic_card,
                      magic_card: magic_card,
                      quantity: 2, foil_quantity: 1,
                      proxy_quantity: 1, proxy_foil_quantity: 1)
        expect(card.display_value).to eq(5 * 15.0)
      end
    end
  end

  describe '#planned?' do
    it 'returns true when staged and no source_collection' do
      card = create(:collection_magic_card, staged: true, source_collection: nil)
      expect(card.planned?).to be true
    end

    it 'returns false when staged but has source_collection' do
      source = create(:collection)
      card = create(:collection_magic_card, staged: true, source_collection: source)
      expect(card.planned?).to be false
    end

    it 'returns false when not staged' do
      card = create(:collection_magic_card, staged: false, source_collection: nil)
      expect(card.planned?).to be false
    end
  end

  describe '#from_owned_collection?' do
    it 'returns true when staged and has a source_collection' do
      source = create(:collection)
      card = create(:collection_magic_card, staged: true, source_collection: source)
      expect(card.from_owned_collection?).to be true
    end

    it 'returns false when staged but no source_collection' do
      card = create(:collection_magic_card, staged: true, source_collection: nil)
      expect(card.from_owned_collection?).to be false
    end

    it 'returns false when not staged' do
      source = create(:collection)
      card = create(:collection_magic_card, staged: false, source_collection: source)
      expect(card.from_owned_collection?).to be false
    end
  end

  describe '#total_staged' do
    it 'sums all staged quantity columns' do
      card = build(:collection_magic_card,
                   staged_quantity: 1, staged_foil_quantity: 2,
                   staged_proxy_quantity: 3, staged_proxy_foil_quantity: 4)
      expect(card.total_staged).to eq(10)
    end
  end

  describe '#display_quantity' do
    it 'returns total_staged when staged' do
      card = build(:collection_magic_card,
                   staged: true,
                   staged_quantity: 2, staged_foil_quantity: 3,
                   staged_proxy_quantity: 1, staged_proxy_foil_quantity: 1)
      expect(card.display_quantity).to eq(7)
    end

    it 'returns total_regular + total_foil when not staged' do
      card = build(:collection_magic_card,
                   staged: false,
                   quantity: 3, foil_quantity: 2,
                   proxy_quantity: 1, proxy_foil_quantity: 1)
      expect(card.display_quantity).to eq(7)
    end
  end

  describe '#commander?' do
    it 'returns true when board_type is commander' do
      expect(build(:collection_magic_card, board_type: 'commander').commander?).to be true
    end

    it 'returns false when board_type is not commander' do
      expect(build(:collection_magic_card, board_type: 'mainboard').commander?).to be false
    end

    it 'returns false when board_type is nil' do
      expect(build(:collection_magic_card, board_type: nil).commander?).to be false
    end
  end
end
