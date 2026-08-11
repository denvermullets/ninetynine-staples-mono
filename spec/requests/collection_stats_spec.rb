require 'rails_helper'

# The dashboard arrives in two requests: the shell, then one tab of panels into its turbo frame.
# What is worth pinning down is the seam between them - who is allowed to ask for a tab, what a tab
# request costs, and what happens to a URL that was only ever meant for a frame. The panels' own
# answers are covered by the service specs.
RSpec.describe 'CollectionStats', type: :request do
  let(:user) { create(:user, username: 'owner') }
  let!(:collection) { create(:collection, user: user, is_public: true) }
  let(:frame) { { 'Turbo-Frame' => 'stats_panel' } }

  before { create(:collection_magic_card, collection: collection, quantity: 1) }

  def queries_for(path, headers: {})
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
    end
    get path, headers: headers
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  describe 'the shell' do
    it 'renders without running a single panel aggregate beyond the headline one' do
      queries = queries_for(collections_stats_path(user.username))

      expect(response).to have_http_status(:ok)
      expect(queries.grep(/FROM "collection_magic_cards"/).size).to eq(1)
    end

    it 'still renders when a stale bookmark names a section that no longer exists' do
      get collections_stats_path(user.username, section: 'made_up')

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'a section' do
    it 'serves each tab to a frame request' do
      CollectionStats::Dashboard::SECTIONS.each_key do |section|
        get collections_stats_section_path(user.username, section), headers: frame

        expect(response).to have_http_status(:ok), "#{section} did not render"
      end
    end

    # a bare partial is not a page: this is what a reload after the tab advanced the URL hits
    it 'sends a plain browser request to the shell with the tab preselected' do
      get collections_stats_section_path(user.username, 'roles')

      expect(response).to redirect_to(collections_stats_path(user.username, section: 'roles'))
    end

    it 'keeps the collection filter when it bounces to the shell' do
      get collections_stats_section_path(user.username, 'cards', collection_id: collection.id)

      expect(response).to redirect_to(
        collections_stats_path(user.username, section: 'cards', collection_id: collection.id)
      )
    end

    it 'refuses a section it does not have' do
      get collections_stats_section_path(user.username, 'made_up'), headers: frame

      expect(response).to have_http_status(:not_found)
    end
  end

  # Scope resolves the requested collection_id inside the collections it already loaded for this
  # username, so a section request cannot be pointed at somebody else's binder by guessing an id
  describe 'visibility' do
    let(:stranger) { create(:user, username: 'stranger') }
    let(:their_collection) { create(:collection, user: stranger, is_public: true) }

    it 'will not report on a collection belonging to another user' do
      get collections_stats_section_path(user.username, 'cards',
                                         collection_id: their_collection.id), headers: frame

      expect(response).to redirect_to(
        collections_stats_path(user.username, section: 'cards', collection_id: their_collection.id)
      )
    end

    it 'leaves a private collection out of what a visitor is shown' do
      private_collection = create(:collection, user: user, is_public: false)

      get collections_stats_section_path(user.username, 'cards',
                                         collection_id: private_collection.id), headers: frame

      expect(response).to redirect_to(
        collections_stats_path(user.username, section: 'cards', collection_id: private_collection.id)
      )
    end
  end
end
