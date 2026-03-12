require 'rails_helper'

RSpec.describe CommanderSpellbook::SyncDeckCombos, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'commander_deck') }
  let(:magic_card1) {
    create(:magic_card, name: 'Dramatic Reversal', scryfall_oracle_id: 'da46904c-8fb8-44c2-b2ab-775a1cc12ec3')
  }
  let(:magic_card2) {
    create(:magic_card, name: 'Isochron Scepter', scryfall_oracle_id: 'ddd649f4-dbaf-48ec-8ff7-95581257772d')
  }

  before do
    create(:collection_magic_card, collection: deck, magic_card: magic_card1, quantity: 1)
    create(:collection_magic_card, collection: deck, magic_card: magic_card2, quantity: 1)
  end

  subject { described_class.call(collection: deck) }

  context 'when API returns combos' do
    let(:api_result) do
      {
        included: [
          {
            spellbook_id: '4821-5261',
            cards: [
              { name: 'Dramatic Reversal', oracle_id: 'da46904c-8fb8-44c2-b2ab-775a1cc12ec3' },
              { name: 'Isochron Scepter', oracle_id: 'ddd649f4-dbaf-48ec-8ff7-95581257772d' }
            ],
            missing_cards: [],
            prerequisites: 'Mana rocks',
            steps: "Step 1\nStep 2",
            results: 'Infinite mana',
            color_identity: 'U',
            permalink: 'https://commanderspellbook.com/combo/4821-5261',
            has_banned_card: false
          }
        ],
        almost_included: [
          {
            spellbook_id: '999-1000',
            cards: [
              { name: 'Dramatic Reversal', oracle_id: 'da46904c-8fb8-44c2-b2ab-775a1cc12ec3' },
              { name: 'Missing Card', oracle_id: 'aabbccdd-1122-3344-5566-778899aabbcc' }
            ],
            missing_cards: [{ name: 'Missing Card', oracle_id: 'aabbccdd-1122-3344-5566-778899aabbcc' }],
            prerequisites: '',
            steps: 'Do stuff',
            results: 'Infinite tokens',
            color_identity: 'UB',
            permalink: 'https://commanderspellbook.com/combo/999-1000',
            has_banned_card: false
          }
        ]
      }
    end

    before do
      allow(CommanderSpellbook::FindCombos).to receive(:call).and_return(api_result)
    end

    it 'creates combos' do
      expect { subject }.to change(Combo, :count).by(2)
    end

    it 'creates combo_cards' do
      subject
      combo = Combo.find_by(spellbook_id: '4821-5261')
      expect(combo.combo_cards.count).to eq(2)
    end

    it 'creates deck_combos with correct types' do
      subject
      expect(deck.deck_combos.included_combos.count).to eq(1)
      expect(deck.deck_combos.almost_included.count).to eq(1)
    end

    it 'creates missing cards for almost_included' do
      subject
      almost = deck.deck_combos.almost_included.first
      expect(almost.deck_combo_missing_cards.count).to eq(1)
      expect(almost.deck_combo_missing_cards.first.card_name).to eq('Missing Card')
    end

    it 'updates combos_checked_at' do
      expect { subject }.to change { deck.reload.combos_checked_at }.from(nil)
    end

    it 'returns success' do
      expect(subject).to eq({ success: true })
    end

    context 'when re-running' do
      before { subject }

      it 'replaces old deck_combos' do
        expect { described_class.call(collection: deck) }.not_to change(DeckCombo, :count)
      end

      it 'updates combo attributes if changed' do
        api_result[:included].first[:results] = 'Infinite mana and storm'
        described_class.call(collection: deck)
        combo = Combo.find_by(spellbook_id: '4821-5261')
        expect(combo.results).to eq('Infinite mana and storm')
      end
    end
  end

  context 'when API returns error' do
    before do
      allow(CommanderSpellbook::FindCombos).to receive(:call)
        .and_return({ error: 'API error: 500' })
    end

    it 'returns error and does not create records' do
      result = subject
      expect(result[:error]).to eq('API error: 500')
      expect(DeckCombo.count).to eq(0)
    end
  end
end
