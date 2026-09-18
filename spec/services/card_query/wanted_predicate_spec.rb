require 'rails_helper'

RSpec.describe CardQuery::WantedPredicate, type: :service do
  let(:user) { create(:user) }
  let(:oracle_id) { SecureRandom.uuid }

  let!(:alpha_bolt) { create(:magic_card, name: 'Lightning Bolt', scryfall_oracle_id: oracle_id) }
  let!(:beta_bolt) { create(:magic_card, name: 'Lightning Bolt', scryfall_oracle_id: oracle_id) }
  let!(:shock) { create(:magic_card, name: 'Shock', scryfall_oracle_id: SecureRandom.uuid) }

  def search(query, wanter_id: user.id, relation: MagicCard.all)
    CardQuery::Builder.call(cards: relation, terms: CardQuery::Parser.call(query: query).terms,
                            wanter_id: wanter_id)
  end

  it 'parses wanted: as a structured term' do
    result = CardQuery::Parser.call(query: 'wanted:true bolt')

    expect(result.terms.map(&:key)).to eq(['wanted'])
    expect(result.free_text).to eq('bolt')
  end

  it 'matches every printing of an any-printing want by oracle id' do
    create(:want_list_item, user: user, magic_card: alpha_bolt)

    expect(search('wanted:true')).to contain_exactly(alpha_bolt, beta_bolt)
  end

  it 'matches only the exact printing of a specific-printing want' do
    create(:want_list_item, :specific_printing, user: user, magic_card: alpha_bolt)

    expect(search('wanted:true')).to contain_exactly(alpha_bolt)
  end

  it 'matches an any-printing want with no oracle id exactly' do
    orphan = create(:magic_card, name: 'Orphan', scryfall_oracle_id: nil)
    create(:magic_card, name: 'Other Orphan', scryfall_oracle_id: nil)
    create(:want_list_item, user: user, magic_card: orphan)

    expect(search('wanted:true')).to contain_exactly(orphan)
  end

  it 'reads a back face as its wanted front face' do
    front = create(:magic_card, name: 'Delver of Secrets', card_uuid: 'front-uuid', card_side: 'a',
                                other_face_uuid: 'back-uuid', scryfall_oracle_id: nil)
    back = create(:magic_card, name: 'Insectile Aberration', card_uuid: 'back-uuid', card_side: 'b',
                               other_face_uuid: 'front-uuid', scryfall_oracle_id: nil)
    create(:want_list_item, :specific_printing, user: user, magic_card: front)

    expect(search('wanted:true')).to contain_exactly(front, back)
  end

  it "ignores other users' wants" do
    create(:want_list_item, user: create(:user), magic_card: shock)

    expect(search('wanted:true')).to be_empty
  end

  it 'inverts for wanted:false and -wanted:true' do
    create(:want_list_item, user: user, magic_card: alpha_bolt)

    expect(search('wanted:false')).to contain_exactly(shock)
    expect(search('-wanted:true')).to contain_exactly(shock)
  end

  it 'yields no rows without a current user' do
    create(:want_list_item, user: user, magic_card: alpha_bolt)

    expect(search('wanted:true', wanter_id: nil)).to be_empty
    expect(search('wanted:false', wanter_id: nil)).to contain_exactly(alpha_bolt, beta_bolt, shock)
  end

  it 'composes with the grouped collections relation without inflating the sums' do
    create(:want_list_item, user: user, magic_card: alpha_bolt)
    collection = create(:collection, user: user)
    create(:collection_magic_card, collection: collection, magic_card: beta_bolt, quantity: 3)
    create(:collection_magic_card, collection: collection, magic_card: shock, quantity: 1)

    grouped = MagicCard.joins(:collection_magic_cards).group('magic_cards.id')
                       .select('magic_cards.*, SUM(collection_magic_cards.quantity) AS total_quantity')

    rows = search('wanted:true', relation: grouped).to_a

    expect(rows.map(&:id)).to eq([beta_bolt.id])
    expect(rows.first.total_quantity).to eq(3)
  end
end
