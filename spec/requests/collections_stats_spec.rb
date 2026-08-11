require 'rails_helper'

RSpec.describe 'Collection analytics', type: :request do
  # explicit usernames - Faker::Internet.username can emit a dot, which the :username
  # route segment swallows as a format and turns into a 404
  let(:user) { create(:user, username: 'owner') }
  let(:stranger) { create(:user, username: 'stranger') }
  let!(:public_collection) { create(:collection, user: user, name: 'Binder', is_public: true) }
  let!(:private_collection) { create(:collection, user: user, name: 'Vault', is_public: false) }

  def login(as:)
    post login_path, params: { email: as.email, password: 'password123' }
  end

  describe 'as the owner' do
    before { login(as: user) }

    it 'renders the aggregate across every collection' do
      get collections_stats_path(user.username)

      expect(response).to have_http_status(:ok)
    end

    it 'renders a single collection when scoped' do
      get collections_stats_path(user.username, collection_id: public_collection.id)

      expect(response).to have_http_status(:ok)
    end

    it 'can scope to its own private collection' do
      get collections_stats_path(user.username, collection_id: private_collection.id)

      expect(response).to have_http_status(:ok)
    end

    it 'renders for a user with no collections at all' do
      empty_user = create(:user, username: 'emptyhanded')
      login(as: empty_user)

      get collections_stats_path(empty_user.username)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'as a visitor' do
    it 'renders the public aggregate' do
      get collections_stats_path(user.username)

      expect(response).to have_http_status(:ok)
    end

    it 'refuses to scope to a private collection' do
      get collections_stats_path(user.username, collection_id: private_collection.id)

      expect(response).to redirect_to(collections_stats_path(user.username))
    end

    it 'leaves private holdings out of the aggregate' do
      card = create(:magic_card, normal_price: 1234.56)
      create(:collection_magic_card, collection: private_collection, magic_card: card, quantity: 1)

      get collections_stats_path(user.username)

      expect(response.body).not_to include('1,234.56')
    end

    # the only guard against a typo'd local in the chart partials - no service spec renders ERB
    it 'renders the chart panels once there is something to chart' do
      boxset = create(:boxset, name: 'Alpha', release_date: '2020-01-01')
      card = create(:magic_card, boxset: boxset, mana_value: 3, normal_price: 5)
      MagicCardColorIdent.create!(magic_card: card, color: Color.find_or_create_by!(name: 'G'))
      create(:collection_magic_card, collection: public_collection, magic_card: card, quantity: 2)

      get collections_stats_path(user.username)

      expect(response.body).to include('data-controller="stats-chart"')
      expect(response.body).to include('Colour Identity')
      expect(response.body).to include('Mana Curve')
      expect(response.body).to include('Set Timeline')
    end

    # the card lists render service rows straight through, so a renamed key is a 500 here and
    # nowhere else - the service specs never touch ERB
    it 'renders the card lists once there is something to rank' do
      # full URLs, the way CardIngestion writes them - a bare filename would go looking for an
      # asset-pipeline entry that does not exist
      card = create(:magic_card, normal_price: 110, price_change_weekly_normal: 10,
                                 image_small: 'https://cards.scryfall.io/small/a.jpg',
                                 image_large: 'https://cards.scryfall.io/large/a.jpg')
      create(:collection_magic_card, collection: public_collection, magic_card: card, quantity: 2)

      get collections_stats_path(user.username)

      expect(response).to have_http_status(:ok)
    end

    it 'renders the movers panel when nothing moved' do
      card = create(:magic_card, normal_price: 5, price_change_weekly_normal: nil)
      create(:collection_magic_card, collection: public_collection, magic_card: card, quantity: 1)

      get collections_stats_path(user.username)

      expect(response).to have_http_status(:ok)
    end

    it 'redirects when handed a collection id belonging to another user' do
      theirs = create(:collection, user: stranger, is_public: true)

      get collections_stats_path(user.username, collection_id: theirs.id)

      expect(response).to redirect_to(collections_stats_path(user.username))
    end
  end

  describe 'an unknown username' do
    it '404s' do
      get collections_stats_path('nobodyhere')

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'query budget' do
    before do
      login(as: user)
      3.times { create(:collection_magic_card, collection: public_collection, quantity: 1) }
    end

    def stats_queries
      queries = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
      end

      get collections_stats_path(user.username)

      queries
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    it 'never falls back to per-card lookups' do
      expect(stats_queries.grep(/FROM "magic_cards" WHERE "magic_cards"\."id" = /)).to be_empty
    end

    it 'stays inside a fixed round-trip budget regardless of collection size' do
      expect(stats_queries.grep(/FROM "collection_magic_cards"/).size).to be <= 12
    end
  end
end
