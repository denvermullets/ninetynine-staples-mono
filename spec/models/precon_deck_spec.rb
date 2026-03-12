require 'rails_helper'

RSpec.describe PreconDeck, type: :model do
  describe 'validations' do
    it 'requires code' do
      deck = PreconDeck.new(file_name: 'test', name: 'Test')
      expect(deck).not_to be_valid
      expect(deck.errors[:code]).to be_present
    end

    it 'requires file_name' do
      deck = PreconDeck.new(code: 'TST', name: 'Test')
      expect(deck).not_to be_valid
      expect(deck.errors[:file_name]).to be_present
    end

    it 'requires name' do
      deck = PreconDeck.new(code: 'TST', file_name: 'test')
      expect(deck).not_to be_valid
      expect(deck.errors[:name]).to be_present
    end

    it 'validates uniqueness of file_name' do
      PreconDeck.create!(code: 'TST', file_name: 'test', name: 'Test')
      duplicate = PreconDeck.new(code: 'TST2', file_name: 'test', name: 'Test 2')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:file_name]).to include('has already been taken')
    end
  end

  describe '#released?' do
    it 'returns false when release_date is nil' do
      deck = PreconDeck.new(release_date: nil)
      expect(deck.released?).to be false
    end

    it 'returns false when release_date is in the future' do
      deck = PreconDeck.new(release_date: 1.week.from_now.to_date)
      expect(deck.released?).to be false
    end

    it 'returns true when release_date is today' do
      deck = PreconDeck.new(release_date: Date.current)
      expect(deck.released?).to be true
    end

    it 'returns true when release_date is in the past' do
      deck = PreconDeck.new(release_date: 1.month.ago.to_date)
      expect(deck.released?).to be true
    end
  end

  describe '#within_sync_window?' do
    it 'returns false when not released' do
      deck = PreconDeck.new(release_date: nil)
      expect(deck.within_sync_window?).to be false
    end

    it 'returns true when released within the last 2 weeks' do
      deck = PreconDeck.new(release_date: 1.week.ago.to_date)
      expect(deck.within_sync_window?).to be true
    end

    it 'returns false when released more than 2 weeks ago' do
      deck = PreconDeck.new(release_date: 3.weeks.ago.to_date)
      expect(deck.within_sync_window?).to be false
    end
  end

  describe '#needs_card_sync?' do
    it 'returns true when released and within sync window' do
      deck = PreconDeck.new(release_date: 1.week.ago.to_date)
      expect(deck.needs_card_sync?).to be true
    end

    it 'returns false when not released' do
      deck = PreconDeck.new(release_date: nil)
      expect(deck.needs_card_sync?).to be false
    end

    it 'returns false when released but outside sync window and has cards' do
      deck = PreconDeck.new(release_date: 1.month.ago.to_date)
      allow(deck.precon_deck_cards).to receive(:empty?).and_return(false)
      expect(deck.needs_card_sync?).to be false
    end
  end
end
