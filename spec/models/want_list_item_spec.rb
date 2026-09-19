require 'rails_helper'

RSpec.describe WantListItem, type: :model do
  let(:user) { create(:user) }
  let(:oracle_id) { SecureRandom.uuid }
  let(:card) { create(:magic_card, scryfall_oracle_id: oracle_id) }
  let(:reprint) { create(:magic_card, scryfall_oracle_id: oracle_id, boxset: create(:boxset)) }

  describe 'validations' do
    it 'refuses an unknown foil preference' do
      item = build(:want_list_item, foil_preference: 'etched')
      expect(item).not_to be_valid
      expect(item.errors[:foil_preference]).to be_present
    end

    it 'refuses a quantity below one' do
      expect(build(:want_list_item, quantity: 0)).not_to be_valid
    end

    it 'accepts the foil trait' do
      expect(build(:want_list_item, :foil)).to be_valid
    end
  end

  describe 'oracle id' do
    it 'is copied from the card' do
      item = create(:want_list_item, magic_card: card)
      expect(item.scryfall_oracle_id).to eq(oracle_id)
    end

    it 'follows the card when the printing changes' do
      item = create(:want_list_item, magic_card: card)
      other = create(:magic_card, scryfall_oracle_id: SecureRandom.uuid, boxset: create(:boxset))
      item.update!(magic_card: other)
      expect(item.scryfall_oracle_id).to eq(other.scryfall_oracle_id)
    end

    it 'stays blank for a card without one' do
      item = create(:want_list_item, magic_card: create(:magic_card, scryfall_oracle_id: nil))
      expect(item.scryfall_oracle_id).to be_nil
    end
  end

  describe 'double-faced cards' do
    let(:front) do
      create(:magic_card, scryfall_oracle_id: oracle_id, card_side: 'a', card_uuid: SecureRandom.uuid)
    end
    let(:back) do
      create(:magic_card, scryfall_oracle_id: oracle_id, card_side: 'b', card_uuid: SecureRandom.uuid,
                          other_face_uuid: front.card_uuid)
    end

    before { front.update!(other_face_uuid: back.card_uuid) }

    it 'stores a want made from the back face against the front face' do
      item = create(:want_list_item, :specific_printing, magic_card: back)
      expect(item.magic_card).to eq(front)
    end

    it 'refuses a second want for the same printing through its other face' do
      create(:want_list_item, :specific_printing, user: user, magic_card: front)
      expect(build(:want_list_item, :specific_printing, user: user, magic_card: back)).not_to be_valid
    end

    it 'matches a specific-printing want from either face' do
      item = create(:want_list_item, :specific_printing, magic_card: front)
      expect(described_class.matching(front)).to contain_exactly(item)
      expect(described_class.matching(back)).to contain_exactly(item)
    end

    it 'keeps a back face whose front is missing' do
      orphan = create(:magic_card, scryfall_oracle_id: oracle_id, card_side: 'b', card_uuid: SecureRandom.uuid,
                                   other_face_uuid: SecureRandom.uuid)
      item = create(:want_list_item, :specific_printing, magic_card: orphan)
      expect(item.magic_card).to eq(orphan)
    end
  end

  describe 'uniqueness' do
    it 'refuses two any-printing rows for the same card' do
      create(:want_list_item, user: user, magic_card: card)
      dupe = build(:want_list_item, user: user, magic_card: reprint)
      expect(dupe).not_to be_valid
      expect { dupe.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'refuses the same printing twice' do
      create(:want_list_item, :specific_printing, user: user, magic_card: card)
      dupe = build(:want_list_item, :specific_printing, user: user, magic_card: card)
      expect(dupe).not_to be_valid
      expect { dupe.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows a specific printing alongside an any-printing row' do
      create(:want_list_item, user: user, magic_card: card)
      expect(create(:want_list_item, :specific_printing, user: user, magic_card: reprint)).to be_persisted
    end

    it 'allows several specific printings of the same card' do
      create(:want_list_item, :specific_printing, user: user, magic_card: card)
      expect(create(:want_list_item, :specific_printing, user: user, magic_card: reprint)).to be_persisted
    end

    it 'allows two users to want the same card' do
      create(:want_list_item, user: user, magic_card: card)
      expect(create(:want_list_item, magic_card: card)).to be_persisted
    end

    it 'allows several any-printing rows for cards without an oracle id' do
      create(:want_list_item, user: user, magic_card: create(:magic_card, scryfall_oracle_id: nil))
      other = create(:want_list_item, user: user,
                                      magic_card: create(:magic_card, scryfall_oracle_id: nil, boxset: create(:boxset)))
      expect(other).to be_persisted
    end
  end

  describe 'scopes' do
    let!(:any) { create(:want_list_item, user: user, magic_card: card) }
    let!(:specific) { create(:want_list_item, :specific_printing, user: user, magic_card: reprint) }

    it 'splits rows by printing mode' do
      expect(described_class.any_printing).to contain_exactly(any)
      expect(described_class.specific_printing).to contain_exactly(specific)
    end

    it 'finds rows by oracle id and by printing' do
      expect(described_class.for_oracle(oracle_id)).to contain_exactly(any, specific)
      expect(described_class.for_printing(reprint.id)).to contain_exactly(specific)
    end
  end

  describe '.matching' do
    let(:third_printing) { create(:magic_card, scryfall_oracle_id: oracle_id, boxset: create(:boxset)) }

    it 'matches an any-printing row from any printing of the card' do
      item = create(:want_list_item, magic_card: card)
      expect(described_class.matching(third_printing)).to contain_exactly(item)
    end

    it 'matches a specific-printing row only from that printing' do
      item = create(:want_list_item, :specific_printing, magic_card: card)
      expect(described_class.matching(card)).to contain_exactly(item)
      expect(described_class.matching(third_printing)).to be_empty
    end

    it 'ignores other cards' do
      create(:want_list_item, magic_card: create(:magic_card, scryfall_oracle_id: SecureRandom.uuid))
      expect(described_class.matching(card)).to be_empty
    end

    it 'falls back to an exact match when the row has no oracle id' do
      blank = create(:magic_card, scryfall_oracle_id: nil)
      item = create(:want_list_item, magic_card: blank)
      expect(described_class.matching(blank)).to contain_exactly(item)
      expect(described_class.matching(card)).to be_empty
    end

    it 'falls back to an exact match when the card has no oracle id' do
      blank = create(:magic_card, scryfall_oracle_id: nil)
      create(:want_list_item, magic_card: card)
      expect(described_class.matching(blank)).to be_empty
    end
  end

  describe '#satisfied_by?' do
    let(:oracle_id) { SecureRandom.uuid }
    let(:wanted) { create(:magic_card, scryfall_oracle_id: oracle_id) }
    let(:reprint) { create(:magic_card, scryfall_oracle_id: oracle_id, boxset: create(:boxset)) }

    it 'agrees with matching for an any-printing row' do
      item = create(:want_list_item, magic_card: wanted)

      expect(item.satisfied_by?(wanted)).to be(true)
      expect(item.satisfied_by?(reprint)).to be(true)
      expect(item.satisfied_by?(create(:magic_card, scryfall_oracle_id: SecureRandom.uuid))).to be(false)
    end

    it 'only accepts the exact printing for a printing-specific row' do
      item = create(:want_list_item, :specific_printing, magic_card: wanted)

      expect(item.satisfied_by?(wanted)).to be(true)
      expect(item.satisfied_by?(reprint)).to be(false)
    end
  end
end
