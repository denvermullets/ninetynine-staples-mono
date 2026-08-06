require 'rails_helper'

RSpec.describe 'Collections', type: :request do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }

  let!(:goblin) do
    typed(create(:magic_card, name: 'Goblin Guide', card_type: 'Creature - Goblin', rarity: 'rare', mana_value: 1),
          'Creature', sub_type: 'Goblin')
  end
  let!(:ritual) do
    typed(create(:magic_card, name: 'Dark Ritual', card_type: 'Instant', rarity: 'common', mana_value: 1), 'Instant')
  end

  def typed(card, type, sub_type: nil)
    MagicCardType.create!(magic_card: card, card_type: CardType.find_or_create_by!(name: type))
    MagicCardSubType.create!(magic_card: card, sub_type: SubType.find_or_create_by!(name: sub_type)) if sub_type
    card
  end

  before do
    create(:collection_magic_card, collection: collection, magic_card: goblin, quantity: 1)
    create(:collection_magic_card, collection: collection, magic_card: ritual, quantity: 1)

    MagicCardColor.create!(magic_card: goblin, color: Color.find_or_create_by!(name: 'R'))
    MagicCardColor.create!(magic_card: ritual, color: Color.find_or_create_by!(name: 'B'))
  end

  def load_cards(search)
    get load_collection_path, params: { username: user.username, collection_id: collection.id, search: search }
    assigns_names
  end

  def assigns_names
    expect(response).to have_http_status(:ok)
    response.body.scan(/Goblin Guide|Dark Ritual/).uniq
  end

  describe 'GET /load_collection' do
    it 'narrows to cards matching an advanced query' do
      expect(load_cards('c:r t:creature r:rare')).to contain_exactly('Goblin Guide')
    end

    it 'combines free text with terms' do
      expect(load_cards('ritual t:instant')).to contain_exactly('Dark Ritual')
    end

    it 'still treats a plain string as a name search' do
      expect(load_cards('goblin')).to contain_exactly('Goblin Guide')
    end

    it 'returns everything when the query is blank' do
      expect(load_cards('')).to contain_exactly('Goblin Guide', 'Dark Ritual')
    end

    it 'does not blow up on a query with an unusable value' do
      expect { load_cards('mv>=banana') }.not_to raise_error
    end

    it 'renders the same page through collections#show' do
      get collection_show_path(username: user.username, collection_id: collection.id),
          params: { search: 'c:r t:creature' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Goblin Guide')
      expect(response.body).not_to include('Dark Ritual')
    end

    it 'does not leak another user\'s cards' do
      stranger_card = typed(create(:magic_card, name: 'Goblin Lackey'), 'Creature', sub_type: 'Goblin')
      create(:collection_magic_card, collection: create(:collection), magic_card: stranger_card, quantity: 1)

      get load_collection_path, params: { username: user.username, search: 'goblin t:creature' }

      expect(response.body).not_to include('Goblin Lackey')
    end
  end
end
