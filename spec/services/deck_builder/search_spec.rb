require 'rails_helper'

RSpec.describe DeckBuilder::Search, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:other_collection) { create(:collection, user: user) }
  let(:magic_card) do
    create(:magic_card, name: 'Lightning Bolt', is_token: false, card_uuid: 'bolt-uuid',
                        mana_value: 1, rarity: 'uncommon', scryfall_oracle_id: SecureRandom.uuid)
  end

  let!(:owned_card) do
    create(:collection_magic_card,
           collection: other_collection,
           magic_card: magic_card,
           quantity: 4,
           foil_quantity: 1,
           staged: false,
           needed: false)
  end

  subject do
    described_class.call(
      query: query,
      user: user,
      deck: deck,
      scope: scope,
      limit: 20
    )
  end

  context 'with a matching owned card' do
    let(:query) { 'Lightning' }
    let(:scope) { 'owned' }

    it 'returns owned card results' do
      results = subject.results
      expect(results).not_to be_empty
      expect(results.first[:type]).to eq(:owned)
      expect(results.first[:card]).to eq(magic_card)
    end

    it 'includes collection info' do
      expect(subject.results.first[:collection_name]).to eq(other_collection.name)
    end
  end

  context 'with scope all' do
    let(:query) { 'Lightning' }
    let(:scope) { 'all' }

    it 'returns results' do
      expect(subject.results).not_to be_empty
    end
  end

  context 'with a blank query' do
    let(:query) { '' }
    let(:scope) { 'all' }

    it 'returns no results' do
      expect(subject.results).to eq([])
    end
  end

  context 'with a too-short query' do
    let(:query) { 'L' }
    let(:scope) { 'all' }

    it 'returns no results' do
      expect(subject.results).to eq([])
    end
  end

  context 'when card is already in deck' do
    let(:query) { 'Lightning' }
    let(:scope) { 'owned' }

    before do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             source_collection_id: other_collection.id,
             staged: true,
             staged_quantity: 1,
             quantity: 0,
             foil_quantity: 0)
    end

    it 'marks the card as already_in_deck' do
      expect(subject.results.first[:already_in_deck]).to be true
    end
  end

  # The point of STA-279: the panel speaks the same query language as the collections page.
  describe 'advanced query terms' do
    let(:scope) { 'owned' }

    context 'when the card matches the term' do
      let(:query) { 'Lightning mv<=3' }

      it 'returns the card' do
        expect(subject.results.map { |r| r[:card] }).to include(magic_card)
      end
    end

    context 'when the card does not match the term' do
      let(:query) { 'Lightning mv>=5' }

      it 'filters it out' do
        expect(subject.results).to be_empty
      end
    end

    context 'with a negated term' do
      let(:query) { 'Lightning -r:uncommon' }

      it 'filters it out' do
        expect(subject.results).to be_empty
      end
    end

    # No free text at all - the two-character floor only applies to the name portion.
    context 'with a term and no free text' do
      let(:query) { 'r:uncommon' }

      it 'still searches' do
        expect(subject.results.map { |r| r[:card] }).to include(magic_card)
      end
    end

    context 'with a role: term' do
      let(:query) { 'role:removal' }

      before { create(:card_role, scryfall_oracle_id: magic_card.scryfall_oracle_id, role: 'removal') }

      it 'returns cards carrying that role' do
        expect(subject.results.map { |r| r[:card] }).to include(magic_card)
      end
    end

    context 'with a role: term the card does not carry' do
      let(:query) { 'role:ramp' }

      before { create(:card_role, scryfall_oracle_id: magic_card.scryfall_oracle_id, role: 'removal') }

      it 'returns nothing' do
        expect(subject.results).to be_empty
      end
    end

    # The newest-printing half of scope: all is a DISTINCT ON with its own LIMIT, so Builder's
    # subqueries have to compose onto that shape too.
    context 'on the all-cards scope' do
      let(:scope) { 'all' }
      let!(:expensive) { create(:magic_card, name: 'Lightning Dragon', is_token: false, mana_value: 5) }

      context 'when the term matches' do
        let(:query) { 'Lightning mv>=5' }

        it 'returns the newest printing' do
          expect(subject.results.map { |r| r[:card] }).to include(expensive)
        end
      end

      context 'when the term does not match' do
        let(:query) { 'Dragon mv<=1' }

        it 'returns nothing' do
          expect(subject.results).to be_empty
        end
      end
    end

    context 'with an unusable value' do
      let(:query) { 'Lightning mv>=banana' }

      it 'reports it rather than folding it into the name search' do
        expect(subject.card_query.ignored).to eq(['mv>=banana'])
        expect(subject.results.map { |r| r[:card] }).to include(magic_card)
      end
    end
  end

  # Ownership terms are HAVING clauses over grouped quantity aggregates this panel does not have.
  # Applying them would silently no-op, so they are refused and reported instead.
  describe 'ownership terms' do
    let(:scope) { 'owned' }

    context 'alongside a name search' do
      let(:query) { 'Lightning qty>=99' }

      it 'reports the key' do
        expect(subject.unsupported).to eq(['qty'])
      end

      it 'does not apply the term' do
        expect(subject.results.map { |r| r[:card] }).to include(magic_card)
      end
    end

    # Left alone this would parse as "advanced", drop to zero usable terms and match everything.
    context 'on its own' do
      let(:query) { 'qty>=1' }

      it 'returns no results' do
        expect(subject.results).to eq([])
      end

      it 'still reports the key' do
        expect(subject.unsupported).to eq(['qty'])
      end
    end
  end
end
