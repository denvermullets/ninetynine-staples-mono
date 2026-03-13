require 'rails_helper'

RSpec.describe SyncDeckCombosJob, type: :job do
  let(:user) { create(:user) }

  describe '#perform' do
    context 'with a valid deck' do
      let(:deck) { create(:collection, user: user, collection_type: 'commander_deck') }

      it 'calls SyncDeckCombos' do
        expect(CommanderSpellbook::SyncDeckCombos).to receive(:call).with(collection: deck)
        described_class.new.perform(deck.id)
      end
    end

    context 'with a non-deck collection' do
      let(:binder) { create(:collection, user: user, collection_type: 'binder') }

      it 'does not call SyncDeckCombos' do
        expect(CommanderSpellbook::SyncDeckCombos).not_to receive(:call)
        described_class.new.perform(binder.id)
      end
    end

    context 'with non-existent collection' do
      it 'does not call SyncDeckCombos' do
        expect(CommanderSpellbook::SyncDeckCombos).not_to receive(:call)
        described_class.new.perform(999_999)
      end
    end
  end
end
