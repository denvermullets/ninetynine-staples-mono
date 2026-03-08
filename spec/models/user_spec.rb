require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'requires email' do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it 'requires email uniqueness (case-insensitive)' do
      create(:user, email: 'test@example.com')
      user = build(:user, email: 'TEST@EXAMPLE.COM')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('has already been taken')
    end

    it 'validates email format' do
      user = build(:user, email: 'not-an-email')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('is invalid')
    end

    it 'accepts a valid email' do
      user = build(:user, email: 'valid@example.com')
      expect(user).to be_valid
    end

    it 'requires username' do
      user = build(:user, username: nil)
      expect(user).not_to be_valid
      expect(user.errors[:username]).to be_present
    end

    it 'validates password minimum length of 10 characters' do
      user = build(:user, password: 'short')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include('is too short (minimum is 10 characters)')
    end

    it 'accepts a password with exactly 10 characters' do
      user = build(:user, password: 'abcdefghij')
      expect(user).to be_valid
    end

    it 'allows updates without providing a password (allow_nil)' do
      user = create(:user)
      user.username = 'new_username'
      expect(user).to be_valid
    end
  end

  describe 'email normalization' do
    it 'strips whitespace from email' do
      user = create(:user, email: '  test@example.com  ')
      expect(user.email).to eq('test@example.com')
    end

    it 'downcases email' do
      user = create(:user, email: 'Test@EXAMPLE.COM')
      expect(user.email).to eq('test@example.com')
    end

    it 'strips and downcases email together' do
      user = create(:user, email: '  Test@Example.COM  ')
      expect(user.email).to eq('test@example.com')
    end
  end

  describe '#confirmed?' do
    it 'returns true when confirmed_at is set' do
      user = build(:user, confirmed_at: Time.current)
      expect(user.confirmed?).to be true
    end

    it 'returns false when confirmed_at is nil' do
      user = build(:user, confirmed_at: nil)
      expect(user.confirmed?).to be false
    end
  end

  describe '#confirm!' do
    it 'sets confirmed_at' do
      user = create(:user, confirmed_at: nil)
      user.confirm!
      expect(user.reload.confirmed_at).to be_present
    end
  end

  describe '#ordered_collections' do
    let(:user) { create(:user) }

    it 'returns collections ordered by id when no custom order is set' do
      c1 = create(:collection, user: user)
      c2 = create(:collection, user: user)
      c3 = create(:collection, user: user)

      result = user.ordered_collections
      expect(result.map(&:id)).to eq([c1.id, c2.id, c3.id])
    end

    it 'respects collection_order when set' do
      c1 = create(:collection, user: user)
      c2 = create(:collection, user: user)
      c3 = create(:collection, user: user)

      user.update!(collection_order: [c3.id, c1.id, c2.id])

      result = user.ordered_collections
      expect(result.map(&:id)).to eq([c3.id, c1.id, c2.id])
    end

    it 'places collections not in the order at the end' do
      c1 = create(:collection, user: user)
      c2 = create(:collection, user: user)
      create(:collection, user: user)

      user.update!(collection_order: [c2.id])

      result = user.ordered_collections
      expect(result.first.id).to eq(c2.id)
      expect(result.map(&:id)).to include(c1.id)
    end
  end

  describe '#move_collection' do
    let(:user) { create(:user) }
    let!(:c1) { create(:collection, user: user) }
    let!(:c2) { create(:collection, user: user) }
    let!(:c3) { create(:collection, user: user) }

    context 'moving a collection down' do
      it 'swaps the collection with the one below it' do
        user.update!(collection_order: [c1.id, c2.id, c3.id])

        user.move_collection(c1.id, 'down')
        expect(user.collection_order).to eq([c2.id, c1.id, c3.id])
      end
    end

    context 'moving a collection up' do
      it 'swaps the collection with the one above it' do
        user.update!(collection_order: [c1.id, c2.id, c3.id])

        user.move_collection(c3.id, 'up')
        expect(user.collection_order).to eq([c1.id, c3.id, c2.id])
      end
    end

    context 'at boundaries' do
      it 'returns false when trying to move the first collection up' do
        user.update!(collection_order: [c1.id, c2.id, c3.id])
        expect(user.move_collection(c1.id, 'up')).to be false
      end

      it 'returns false when trying to move the last collection down' do
        user.update!(collection_order: [c1.id, c2.id, c3.id])
        expect(user.move_collection(c3.id, 'down')).to be false
      end
    end

    context 'when no custom order exists' do
      it 'initializes order from collection ids and performs the move' do
        result = user.move_collection(c1.id, 'down')
        expect(result).to be_truthy
        expect(user.collection_order).to eq([c2.id, c1.id, c3.id])
      end
    end
  end
end
