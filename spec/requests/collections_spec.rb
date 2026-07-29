require 'rails_helper'

RSpec.describe 'Collections', type: :request do
  # pinned: Faker usernames can contain a dot, which the route's (.:format) segment
  # swallows, producing a spurious 404
  let(:user) { create(:user, username: 'collector') }
  let(:collection) { create(:collection, user: user, is_public: true) }
  let(:boxset) { create(:boxset, code: 'TST', keyrune_code: 'TST') }

  describe 'GET /collections/:username/:collection_id' do
    let!(:regular) do
      create(:magic_card, name: 'Regular Printing', normal_price: 12.24, foil_price: 0.0,
                          boxset: boxset, rarity: 'rare', card_number: '124')
    end
    let!(:foil_only) do
      create(:magic_card, name: 'Foil Printing', normal_price: 1.50, foil_price: 70.55,
                          boxset: boxset, rarity: 'mythic', card_number: '189')
    end

    before do
      create(:collection_magic_card, collection: collection, magic_card: regular, quantity: 1, foil_quantity: 0)
      create(:collection_magic_card, collection: collection, magic_card: foil_only, quantity: 0, foil_quantity: 1)
    end

    it 'renders the collection table' do
      get collection_show_path(username: user.username, collection_id: collection.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Regular Printing')
      expect(response.body).to include('Foil Printing')
    end

    it 'sorts a foil-only printing above a cheaper regular printing' do
      get collection_show_path(username: user.username, collection_id: collection.id)

      expect(response.body.index('Foil Printing')).to be < response.body.index('Regular Printing')
    end

    it 'does not load every card in the collection to render one page' do
      loaded = 0
      sub = ActiveSupport::Notifications.subscribe('instantiation.active_record') do |*, payload|
        loaded += payload[:record_count].to_i if payload[:class_name] == 'MagicCard'
      end

      get collection_show_path(username: user.username, collection_id: collection.id)

      ActiveSupport::Notifications.unsubscribe(sub)
      # 2 cards in the collection; a full-relation load would double-count them
      # (once for the present? check, once for the paginated fetch).
      expect(loaded).to eq(2)
    end

    it 'renders an empty collection without error' do
      empty = create(:collection, user: user, is_public: true)

      get collection_show_path(username: user.username, collection_id: empty.id)

      expect(response).to have_http_status(:ok)
    end
  end
end
