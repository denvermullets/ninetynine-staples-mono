require 'rails_helper'

RSpec.describe MagicCard, type: :model do
  describe '#primary_type' do
    it 'returns Creature for a creature card' do
      card = build(:magic_card, card_type: 'Creature - Human Wizard')
      expect(card.primary_type).to eq('Creature')
    end

    it 'returns Instant for an instant card' do
      card = build(:magic_card, card_type: 'Instant')
      expect(card.primary_type).to eq('Instant')
    end

    it 'returns Enchantment for a legendary enchantment' do
      card = build(:magic_card, card_type: 'Legendary Enchantment')
      expect(card.primary_type).to eq('Enchantment')
    end

    it 'returns Creature for an artifact creature (Creature checked first)' do
      card = build(:magic_card, card_type: 'Artifact Creature - Golem')
      expect(card.primary_type).to eq('Creature')
    end

    it 'returns Land for a basic land' do
      card = build(:magic_card, card_type: 'Basic Land - Forest')
      expect(card.primary_type).to eq('Land')
    end

    it 'returns Planeswalker for a planeswalker card' do
      card = build(:magic_card, card_type: 'Legendary Planeswalker - Jace')
      expect(card.primary_type).to eq('Planeswalker')
    end

    it 'returns Sorcery for a sorcery card' do
      card = build(:magic_card, card_type: 'Sorcery')
      expect(card.primary_type).to eq('Sorcery')
    end

    it 'returns Battle for a battle card' do
      card = build(:magic_card, card_type: 'Battle - Siege')
      expect(card.primary_type).to eq('Battle')
    end

    it 'returns the first segment when no recognized type is found' do
      card = build(:magic_card, card_type: 'Tribal - Goblin')
      expect(card.primary_type).to eq('Tribal')
    end

    it 'returns nil when card_type is nil' do
      card = build(:magic_card, card_type: nil)
      expect(card.primary_type).to be_nil
    end
  end

  describe '#double_faced?' do
    it 'returns true when other_face_uuid is present' do
      card = build(:magic_card, other_face_uuid: 'some-uuid-value')
      expect(card.double_faced?).to be true
    end

    it 'returns false when other_face_uuid is nil' do
      card = build(:magic_card, other_face_uuid: nil)
      expect(card.double_faced?).to be false
    end

    it 'returns false when other_face_uuid is an empty string' do
      card = build(:magic_card, other_face_uuid: '')
      expect(card.double_faced?).to be false
    end
  end

  describe '#other_face' do
    it 'returns nil when other_face_uuid is not present' do
      card = build(:magic_card, other_face_uuid: nil)
      expect(card.other_face).to be_nil
    end

    it 'finds the other card when other_face_uuid is set' do
      front_face = create(:magic_card, card_uuid: 'front-uuid-123')
      back_face = create(:magic_card, card_uuid: 'back-uuid-456')
      front_face.update_column(:other_face_uuid, 'back-uuid-456')

      expect(front_face.other_face).to eq(back_face)
    end

    it 'returns nil when other_face_uuid does not match any card' do
      card = create(:magic_card)
      card.update_column(:other_face_uuid, 'nonexistent-uuid')

      expect(card.other_face).to be_nil
    end
  end

  describe '#display_price' do
    it 'returns normal_price when it is positive' do
      card = build(:magic_card, normal_price: 5.0, foil_price: 10.0)
      expect(card.display_price).to eq(5.0)
    end

    it 'falls back to foil_price when normal_price is zero' do
      card = build(:magic_card, normal_price: 0, foil_price: 10.0)
      expect(card.display_price).to eq(10.0)
    end

    it 'falls back to foil_price when normal_price is nil' do
      card = build(:magic_card, normal_price: nil, foil_price: 8.5)
      expect(card.display_price).to eq(8.5)
    end

    it 'returns 0.0 when both prices are nil' do
      card = build(:magic_card, normal_price: nil, foil_price: nil)
      expect(card.display_price).to eq(0.0)
    end
  end

  describe '#user_owned_copies' do
    it 'returns an empty array when user is nil' do
      card = build(:magic_card)
      expect(card.user_owned_copies(nil)).to eq([])
    end

    it 'returns non-staged, non-needed collection_magic_cards owned by the user' do
      user = create(:user)
      collection = create(:collection, user: user)
      card = create(:magic_card)
      owned_copy = create(:collection_magic_card,
                          magic_card: card,
                          collection: collection,
                          staged: false,
                          needed: false)

      result = card.user_owned_copies(user)
      expect(result).to include(owned_copy)
    end

    it 'excludes staged cards' do
      user = create(:user)
      collection = create(:collection, user: user)
      card = create(:magic_card)
      create(:collection_magic_card,
             magic_card: card,
             collection: collection,
             staged: true,
             needed: false)

      result = card.user_owned_copies(user)
      expect(result).to be_empty
    end

    it 'excludes needed cards' do
      user = create(:user)
      collection = create(:collection, user: user)
      card = create(:magic_card)
      create(:collection_magic_card,
             magic_card: card,
             collection: collection,
             staged: false,
             needed: true)

      result = card.user_owned_copies(user)
      expect(result).to be_empty
    end

    it 'excludes cards owned by a different user' do
      user = create(:user)
      other_user = create(:user)
      other_collection = create(:collection, user: other_user)
      card = create(:magic_card)
      create(:collection_magic_card,
             magic_card: card,
             collection: other_collection,
             staged: false,
             needed: false)

      result = card.user_owned_copies(user)
      expect(result).to be_empty
    end
  end

  describe '#price_change' do
    it 'delegates to the price trend service' do
      card = build(:magic_card)
      mock_service = instance_double(MagicCards::PriceTrend, price_change: 1.25)
      allow(MagicCards::PriceTrend).to receive(:new).and_return(mock_service)

      expect(card.price_change).to eq(1.25)
    end
  end

  describe '#price_trend' do
    it 'delegates to the price trend service with default arguments' do
      card = build(:magic_card)
      mock_service = instance_double(MagicCards::PriceTrend, trend: :rising)
      allow(MagicCards::PriceTrend).to receive(:new).and_return(mock_service)

      expect(card.price_trend).to eq(:rising)
      expect(mock_service).to have_received(:trend).with(days: 7, threshold_percent: 5.0)
    end

    it 'passes custom arguments to the price trend service' do
      card = build(:magic_card)
      mock_service = instance_double(MagicCards::PriceTrend, trend: :stable)
      allow(MagicCards::PriceTrend).to receive(:new).and_return(mock_service)

      expect(card.price_trend(days: 30, threshold_percent: 10.0)).to eq(:stable)
      expect(mock_service).to have_received(:trend).with(days: 30, threshold_percent: 10.0)
    end
  end
end
