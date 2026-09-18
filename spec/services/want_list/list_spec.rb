require 'rails_helper'

RSpec.describe WantList::List, type: :service do
  let(:user) { create(:user) }
  let(:binder) { create(:collection, user: user) }
  let(:oracle_id) { SecureRandom.uuid }
  let(:card) do
    create(:magic_card, name: 'Mox Diamond', scryfall_oracle_id: oracle_id, normal_price: 500, foil_price: 900)
  end
  let(:other_printing) do
    create(:magic_card, name: 'Mox Diamond', scryfall_oracle_id: oracle_id, boxset: create(:boxset))
  end

  def list(**)
    described_class.call(user: user, collection_ids: [binder.id], **)
  end

  def owned_quantity(**)
    list(**)[:items].first.owned_quantity
  end

  it "lists only this user's wants" do
    mine = create(:want_list_item, user: user, magic_card: card)
    create(:want_list_item, magic_card: card)

    expect(list[:items]).to contain_exactly(mine)
  end

  describe 'owned copies' do
    it 'counts the wanted printing' do
      create(:want_list_item, user: user, magic_card: card)
      create(:collection_magic_card, collection: binder, magic_card: card, quantity: 2, foil_quantity: 1)

      expect(owned_quantity).to eq(3)
    end

    it 'counts another printing for an any-printing want' do
      create(:want_list_item, user: user, magic_card: card)
      create(:collection_magic_card, collection: binder, magic_card: other_printing)

      expect(owned_quantity).to eq(1)
    end

    it 'ignores another printing for a specific want' do
      create(:want_list_item, :specific_printing, user: user, magic_card: card)
      create(:collection_magic_card, collection: binder, magic_card: other_printing)

      expect(owned_quantity).to eq(0)
    end

    it 'does not let a non-foil copy fill a foil-only want' do
      create(:want_list_item, :foil, user: user, magic_card: card)
      create(:collection_magic_card, collection: binder, magic_card: card, quantity: 1, foil_quantity: 0)

      expect(owned_quantity).to eq(0)
    end

    it 'leaves out staged and needed rows' do
      create(:want_list_item, user: user, magic_card: card)
      create(:collection_magic_card, collection: binder, magic_card: card, staged: true)
      create(:collection_magic_card, collection: binder, magic_card: card, needed: true)

      expect(owned_quantity).to eq(0)
    end

    it 'leaves out collections the viewer was not given' do
      create(:want_list_item, user: user, magic_card: card)
      hidden = create(:collection, user: user)
      create(:collection_magic_card, collection: hidden, magic_card: card)

      expect(owned_quantity).to eq(0)
    end

    it 'counts nothing when there are no collections to check' do
      create(:want_list_item, user: user, magic_card: card)

      result = described_class.call(user: user, collection_ids: [])

      expect(result[:items].first.owned_quantity).to eq(0)
      expect(result[:counts][:owned]).to eq(0)
    end
  end

  describe 'filters and counts' do
    let(:cheap) { create(:magic_card, name: 'Arcane Signet', normal_price: 1, foil_price: 40) }
    let!(:any_want) { create(:want_list_item, user: user, magic_card: card, created_at: 2.days.ago) }
    let!(:specific_want) { create(:want_list_item, :specific_printing, user: user, magic_card: cheap) }

    before { create(:collection_magic_card, collection: binder, magic_card: cheap) }

    it 'counts every pill with no filter applied' do
      expect(list(filter: 'owned')[:counts]).to eq(all: 2, any_printing: 1, specific: 1, owned: 1)
    end

    it 'narrows to any-printing, specific and now-owned wants' do
      expect(list(filter: 'any_printing')[:items]).to contain_exactly(any_want)
      expect(list(filter: 'specific')[:items]).to contain_exactly(specific_want)
      expect(list(filter: 'owned')[:items]).to contain_exactly(specific_want)
    end

    it 'falls back to everything for a filter it does not know' do
      expect(list(filter: 'nonsense')[:items]).to contain_exactly(any_want, specific_want)
    end

    it 'sorts by name, price and date added' do
      expect(list(sort: 'name')[:items].to_a).to eq([specific_want, any_want])
      expect(list(sort: 'price')[:items].to_a).to eq([any_want, specific_want])
      expect(list(sort: 'added')[:items].to_a).to eq([specific_want, any_want])
    end

    it 'prices a foil-only want at its foil price' do
      specific_want.update!(foil_preference: 'foil')
      any_want.update!(foil_preference: 'non_foil')
      card.update!(normal_price: 30)

      expect(list(sort: 'price')[:items].to_a).to eq([specific_want, any_want])
    end
  end
end
