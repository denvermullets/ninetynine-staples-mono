require 'rails_helper'

RSpec.describe CollectionRecord::BulkApply, type: :service do
  let(:user) { create(:user) }
  let(:binder) { create(:collection, user: user, name: 'Binder A') }
  let(:deck_box) { create(:collection, user: user, name: 'Deck Box') }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0) }

  def row(overrides = {})
    {
      magic_card_id: magic_card.id, card_uuid: nil,
      from_collection_id: described_class::BRAND_NEW, to_collection_id: deck_box.id,
      quantity: 0, foil_quantity: 0, proxy_quantity: 0, proxy_foil_quantity: 0
    }.merge(overrides)
  end

  subject { described_class.call(rows: rows, user: user) }

  describe 'brand new rows' do
    context 'when the card is not in the destination yet' do
      let(:rows) { [row(quantity: 3, foil_quantity: 1)] }

      it 'creates the record at the entered totals' do
        expect { subject }.to change { deck_box.collection_magic_cards.count }.by(1)

        card = deck_box.collection_magic_cards.first
        expect(card.quantity).to eq(3)
        expect(card.foil_quantity).to eq(1)
      end

      it 'reports success and counts the row' do
        expect(subject[:success]).to be true
        expect(subject[:processed_count]).to eq(1)
      end
    end

    context 'when the card is already in the destination' do
      let!(:existing) do
        create(:collection_magic_card, collection: deck_box, magic_card: magic_card,
                                       quantity: 2, foil_quantity: 0)
      end

      context 'and the entered amounts are higher' do
        let(:rows) { [row(quantity: 5)] }

        it 'treats the amounts as totals rather than adding to them' do
          subject
          expect(existing.reload.quantity).to eq(5)
        end
      end

      context 'and the entered amounts match what is already there' do
        let(:rows) { [row(quantity: 2)] }

        it 'is a noop that touches nothing' do
          expect { subject }.not_to(change { existing.reload.updated_at })
        end

        it 'is not counted as a processed change' do
          expect(subject[:success]).to be true
          expect(subject[:processed_count]).to eq(0)
        end
      end
    end
  end

  describe 'transfer rows' do
    let!(:source) do
      create(:collection_magic_card, collection: binder, magic_card: magic_card,
                                     quantity: 4, foil_quantity: 1)
    end
    let(:rows) { [row(from_collection_id: binder.id, quantity: 2)] }

    it 'moves the entered amount as a delta' do
      subject

      expect(source.reload.quantity).to eq(2)
      expect(deck_box.collection_magic_cards.first.quantity).to eq(2)
    end

    it 'reports success' do
      expect(subject[:success]).to be true
      expect(subject[:processed_count]).to eq(1)
    end

    context 'when the source does not hold enough' do
      let(:rows) { [row(from_collection_id: binder.id, quantity: 99)] }

      it 'fails the row and leaves the source alone' do
        expect(subject[:success]).to be false
        expect(subject[:results].first[:error]).to eq('Not enough cards to transfer')
        expect(source.reload.quantity).to eq(4)
      end
    end
  end

  describe 'skipped rows' do
    context 'when every amount is zero' do
      let(:rows) { [row] }

      it 'writes nothing and processes nothing' do
        expect { subject }.not_to(change { CollectionMagicCard.count })
        expect(subject[:processed_count]).to eq(0)
      end
    end

    context 'when the destination is missing' do
      let(:rows) { [row(to_collection_id: nil, quantity: 3)] }

      it 'writes nothing' do
        expect { subject }.not_to(change { CollectionMagicCard.count })
      end
    end
  end

  describe 'validation errors' do
    context "when 'Brand new' is the destination" do
      let(:rows) { [row(from_collection_id: binder.id, to_collection_id: described_class::BRAND_NEW, quantity: 1)] }

      it 'rejects the row' do
        expect(subject[:success]).to be false
        expect(subject[:results].first[:error]).to eq("'Brand new' cannot be the destination")
      end
    end

    context 'when FROM and TO are the same collection' do
      let(:rows) { [row(from_collection_id: deck_box.id, quantity: 1)] }

      it 'rejects the row' do
        expect(subject[:success]).to be false
        expect(subject[:results].first[:error]).to eq('FROM and TO must differ')
      end
    end

    context 'when a collection belongs to someone else' do
      let(:other_collection) { create(:collection, user: create(:user)) }
      let(:rows) { [row(to_collection_id: other_collection.id, quantity: 1)] }

      it 'rejects the row' do
        expect(subject[:success]).to be false
        expect(subject[:results].first[:error]).to eq('Collection does not belong to current user')
      end
    end

    it 'names the card so the failure can be reported to the user' do
      rows = [row(from_collection_id: deck_box.id, quantity: 1)]
      result = described_class.call(rows: rows, user: user)

      expect(result[:results].first[:name]).to eq(magic_card.name)
    end
  end

  describe 'all-or-nothing behaviour' do
    let(:rows) do
      [
        row(quantity: 3),
        row(from_collection_id: deck_box.id, quantity: 1)
      ]
    end

    it 'rolls the whole batch back when any row errors' do
      expect { subject }.not_to(change { CollectionMagicCard.count })
      expect(subject[:success]).to be false
    end
  end
end
