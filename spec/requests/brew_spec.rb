require 'rails_helper'

# Nothing here renders the page. A request spec that renders the full layout needs a built
# tailwind.css, which CI does not have, so what the page SHOWS is covered by the service specs
# (Commanders::Discovery, CollectionStats::BuildableProfile) and what is left for this file is the
# seam around it: whose collection you are allowed to brew from, and that the route resolves at all.
#
# Usernames are set explicitly rather than left to the factory's Faker default - a generated username
# containing a dot is read as a format extension by the :username routes and 404s at random.
RSpec.describe 'Brew', type: :request do
  let(:user) { create(:user, username: 'brewer') }
  let!(:collection) { create(:collection, user: user, is_public: true) }

  it 'refuses a username it does not have' do
    get collection_brew_path('nobody')

    expect(response).to have_http_status(:not_found)
  end

  # The specific collections/:username routes all have to resolve ahead of the
  # collections/:username(/:collection_id) catch-all, or "brew" is read as a collection id.
  it 'routes ahead of the collection show catch-all' do
    recognized = Rails.application.routes.recognize_path("/collections/#{user.username}/brew")

    expect(recognized).to include(controller: 'brew', action: 'index')
  end

  describe 'visibility' do
    it 'will not brew from a collection belonging to another user' do
      stranger = create(:user, username: 'stranger')
      theirs = create(:collection, user: stranger, is_public: true)

      get collection_brew_path(user.username, collection_id: theirs.id)

      expect(response).to redirect_to(collection_brew_path(user.username))
    end

    it 'leaves a private collection out of what a visitor is shown' do
      private_collection = create(:collection, user: user, is_public: false)

      get collection_brew_path(user.username, collection_id: private_collection.id)

      expect(response).to redirect_to(collection_brew_path(user.username))
    end
  end

  # Every filter is whitelisted against a frozen constant with a fallback, so a hand-edited URL
  # cannot reach the sort or the band with anything the services do not understand. Asserted on the
  # controller rather than through a request, because reading the answer off the page would mean
  # rendering it.
  describe 'filter whitelisting' do
    it 'falls back to the default sort, band and floor when handed nonsense' do
      controller = BrewController.new
      controller.params = ActionController::Parameters.new(sort: 'nonsense', band: 'nonsense',
                                                           floor: 'nonsense')
      controller.send(:read_view_options)

      expect(controller.instance_values.values_at('sort', 'band', 'floor'))
        .to eq(%w[buildable all all])
    end

    it 'only offers floors the discovery service can be handed' do
      expect(BrewController::FLOORS.values).to all(be_between(0.0, 1.0))
    end
  end
end
