require 'rails_helper'

RSpec.describe DeckBuilder::SourceShortfall, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:binder) { create(:collection, user: user, name: 'Binder') }
  let(:plains) { create(:magic_card, name: 'Plains') }

  def stage(card, **quantities)
    create(:collection_magic_card, collection: deck, magic_card: card, source_collection_id: binder.id,
                                   staged: true, quantity: 0, foil_quantity: 0, **quantities)
  end

  def hold(card, **quantities)
    create(:collection_magic_card, collection: binder, magic_card: card, staged: false, needed: false,
                                   **quantities)
  end

  describe '.first' do
    it 'names the first type the source cannot cover' do
      result = described_class.first(needed: { regular: 1, foil: 1 }, available: { regular: 1, foil: 0 })

      expect(result).to eq(type: :foil, needed: 1, available: 0)
    end

    it 'is nil when every type is covered' do
      expect(described_class.first(needed: { regular: 2 }, available: { regular: 2, foil: 0 })).to be_nil
    end
  end

  describe '.call' do
    subject(:issues) { described_class.call(deck: deck) }

    it 'flags a foil copy staged from a source that only holds a regular one' do
      hold(plains, quantity: 1, foil_quantity: 0)
      staged = stage(plains, staged_foil_quantity: 1)

      expect(issues).to eq(staged.id => 'Binder has 0 foil (1 regular), 1 staged')
    end

    it 'flags a row whose printing is gone from the source' do
      staged = stage(plains, staged_quantity: 1)

      expect(issues).to eq(staged.id => 'Binder no longer has this printing')
    end

    it 'leaves rows the source covers alone' do
      hold(plains, quantity: 3)
      stage(plains, staged_quantity: 3)

      expect(issues).to be_empty
    end

    it 'ignores planned rows, which have no source to check' do
      create(:collection_magic_card, collection: deck, magic_card: plains, staged: true, staged_quantity: 1,
                                     source_collection_id: nil)

      expect(issues).to be_empty
    end

    it 'agrees with Finalize about which deck it refuses' do
      hold(plains, quantity: 1)
      stage(plains, staged_foil_quantity: 1)

      expect(issues).not_to be_empty
      expect(DeckBuilder::Finalize.call(deck: deck)).to include(success: false, error: 'Only 0 foil Plains available')
    end
  end
end
