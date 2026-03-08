require 'rails_helper'

RSpec.describe Collection, type: :model do
  describe 'validations' do
    it 'requires name' do
      collection = build(:collection, name: nil)
      expect(collection).not_to be_valid
      expect(collection.errors[:name]).to be_present
    end

    it 'requires description' do
      collection = build(:collection, description: nil)
      expect(collection).not_to be_valid
      expect(collection.errors[:description]).to be_present
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }

    describe '.by_user' do
      it 'returns collections belonging to the given user' do
        collection = create(:collection, user: user)
        create(:collection, user: other_user)

        expect(Collection.by_user(user.id)).to eq([collection])
      end
    end

    describe '.by_type' do
      it 'returns collections matching the given type' do
        binder = create(:collection, user: user, collection_type: 'binder')
        create(:collection, user: user, collection_type: 'deck')

        expect(Collection.by_type('binder')).to eq([binder])
      end
    end

    describe '.decks' do
      it 'returns collections with collection_type "deck"' do
        deck = create(:collection, user: user, collection_type: 'deck')
        create(:collection, user: user, collection_type: 'binder')

        expect(Collection.decks).to include(deck)
      end

      it 'returns collections with collection_type ending in "_deck"' do
        commander_deck = create(:collection, user: user, collection_type: 'commander_deck')
        create(:collection, user: user, collection_type: 'binder')

        expect(Collection.decks).to include(commander_deck)
      end

      it 'does not return non-deck collections' do
        create(:collection, user: user, collection_type: 'binder')

        expect(Collection.decks).to be_empty
      end
    end

    describe '.visible_to_public' do
      it 'returns collections where is_public is true' do
        public_collection = create(:collection, user: user, is_public: true)
        create(:collection, user: user, is_public: false)

        expect(Collection.visible_to_public).to eq([public_collection])
      end
    end
  end

  describe '.deck_type?' do
    it 'returns true for "deck"' do
      expect(Collection.deck_type?('deck')).to be true
    end

    it 'returns true for types ending in "_deck"' do
      expect(Collection.deck_type?('commander_deck')).to be true
    end

    it 'returns false for non-deck types' do
      expect(Collection.deck_type?('binder')).to be false
    end

    it 'returns falsey for nil' do
      expect(Collection.deck_type?(nil)).to be_falsey
    end
  end

  describe '#total_estimated_value' do
    it 'returns the sum of total_value and proxy_total_value' do
      collection = build(:collection, total_value: 100.50, proxy_total_value: 25.75)
      expect(collection.total_estimated_value).to eq(126.25)
    end
  end

  describe '#total_cards' do
    it 'returns the sum of all quantity fields' do
      collection = build(
        :collection,
        total_quantity: 10,
        total_foil_quantity: 5,
        total_proxy_quantity: 3,
        total_proxy_foil_quantity: 2
      )
      expect(collection.total_cards).to eq(20)
    end
  end

  describe '#total_real_cards' do
    it 'returns the sum of total_quantity and total_foil_quantity' do
      collection = build(:collection, total_quantity: 10, total_foil_quantity: 5)
      expect(collection.total_real_cards).to eq(15)
    end
  end

  describe '#total_proxy_cards' do
    it 'returns the sum of proxy quantities' do
      collection = build(:collection, total_proxy_quantity: 3, total_proxy_foil_quantity: 2)
      expect(collection.total_proxy_cards).to eq(5)
    end
  end

  describe '#deck?' do
    it 'returns true when collection_type is "deck"' do
      expect(build(:collection, collection_type: 'deck').deck?).to be true
    end

    it 'returns false when collection_type is not "deck"' do
      expect(build(:collection, collection_type: 'binder').deck?).to be false
    end
  end

  describe '#commander_deck?' do
    it 'returns true when collection_type is "commander_deck"' do
      expect(build(:collection, collection_type: 'commander_deck').commander_deck?).to be true
    end

    it 'returns false otherwise' do
      expect(build(:collection, collection_type: 'deck').commander_deck?).to be false
    end
  end

  describe '#hidden?' do
    it 'returns true when is_public is false' do
      expect(build(:collection, is_public: false).hidden?).to be true
    end

    it 'returns false when is_public is true' do
      expect(build(:collection, is_public: true).hidden?).to be false
    end
  end

  describe '#in_build_mode?' do
    it 'returns true when staged collection_magic_cards exist' do
      collection = create(:collection)
      create(:collection_magic_card, collection: collection, staged: true)
      expect(collection.in_build_mode?).to be true
    end

    it 'returns false when no staged collection_magic_cards exist' do
      collection = create(:collection)
      create(:collection_magic_card, collection: collection, staged: false)
      expect(collection.in_build_mode?).to be false
    end
  end

  describe '#staged_cards_count' do
    it 'sums staged quantities for staged cards only' do
      collection = create(:collection)
      create(:collection_magic_card, collection: collection, staged: true, staged_quantity: 3, staged_foil_quantity: 2)
      create(:collection_magic_card, collection: collection, staged: true, staged_quantity: 1, staged_foil_quantity: 1)
      create(:collection_magic_card, collection: collection, staged: false, staged_quantity: 10,
                                     staged_foil_quantity: 10)

      expect(collection.staged_cards_count).to eq(7)
    end

    it 'returns 0 when no staged cards exist' do
      collection = create(:collection)
      expect(collection.staged_cards_count).to eq(0)
    end
  end

  describe '#needed_cards_count' do
    it 'sums quantities for needed cards only' do
      collection = create(:collection)
      create(:collection_magic_card, collection: collection, needed: true, quantity: 4, foil_quantity: 1)
      create(:collection_magic_card, collection: collection, needed: true, quantity: 2, foil_quantity: 3)
      create(:collection_magic_card, collection: collection, needed: false, quantity: 99, foil_quantity: 99)

      expect(collection.needed_cards_count).to eq(10)
    end

    it 'returns 0 when no needed cards exist' do
      collection = create(:collection)
      expect(collection.needed_cards_count).to eq(0)
    end
  end

  describe '.aggregate_history' do
    it 'aggregates collection_history across multiple collections' do
      user = create(:user)
      c1 = create(:collection, user: user, collection_history: { '2025-01-01' => 10.0, '2025-01-02' => 20.0 })
      c2 = create(:collection, user: user, collection_history: { '2025-01-01' => 5.0, '2025-01-03' => 15.0 })

      result = Collection.aggregate_history([c1, c2])
      expect(result).to eq({ '2025-01-01' => 15.0, '2025-01-02' => 20.0, '2025-01-03' => 15.0 })
    end

    it 'returns a sorted hash by date' do
      user = create(:user)
      c1 = create(:collection, user: user, collection_history: { '2025-01-03' => 30.0, '2025-01-01' => 10.0 })

      result = Collection.aggregate_history([c1])
      expect(result.keys).to eq(%w[2025-01-01 2025-01-03])
    end

    it 'skips collections without collection_history' do
      user = create(:user)
      c1 = create(:collection, user: user, collection_history: { '2025-01-01' => 10.0 })
      c2 = create(:collection, user: user, collection_history: nil)

      result = Collection.aggregate_history([c1, c2])
      expect(result).to eq({ '2025-01-01' => 10.0 })
    end

    it 'returns an empty hash when no collections have history' do
      expect(Collection.aggregate_history([])).to eq({})
    end
  end
end
