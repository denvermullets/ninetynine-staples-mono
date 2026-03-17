require 'rails_helper'

RSpec.describe SyncDeckCombosJob, type: :job do
  let(:user) { create(:user) }

  describe '#perform' do
    context 'with a valid deck' do
      let(:deck) { create(:collection, user: user, collection_type: 'commander_deck') }

      it 'calls SyncDeckCombos and broadcasts results' do
        expect(CommanderSpellbook::SyncDeckCombos).to receive(:call)
          .with(collection: deck)
          .and_return({ success: true })

        expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
          "user_#{user.id}_notifications",
          target: 'toasts',
          html: a_string_including('bg-accent-50')
        )

        expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)
          .with("user_#{user.id}_notifications")

        described_class.new.perform(deck.id)
      end

      it 'broadcasts combo count when combos exist' do
        combo = Combo.create!(spellbook_id: 'combo-1')
        DeckCombo.create!(collection: deck, combo: combo, combo_type: 'included')

        allow(CommanderSpellbook::SyncDeckCombos).to receive(:call).and_return({ success: true })
        allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)

        expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
          "user_#{user.id}_notifications",
          target: 'toasts',
          html: a_string_including('Found 1 combo')
        )

        described_class.new.perform(deck.id)
      end
    end

    context 'when sync returns an error' do
      let(:deck) { create(:collection, user: user, collection_type: 'commander_deck') }

      it 'broadcasts an error toast' do
        allow(CommanderSpellbook::SyncDeckCombos).to receive(:call)
          .and_return({ error: 'API unavailable' })

        expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
          "user_#{user.id}_notifications",
          target: 'toasts',
          html: a_string_including('bg-accent-100', 'API unavailable')
        )

        expect(Turbo::StreamsChannel).not_to receive(:broadcast_refresh_to)

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
