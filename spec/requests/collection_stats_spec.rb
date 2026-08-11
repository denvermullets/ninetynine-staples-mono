require 'rails_helper'

# The dashboard arrives in two requests: the shell, then one tab of panels into its turbo frame.
# What is worth pinning down is the seam between them - who is allowed to ask for a tab, what a tab
# request costs, and what happens to a URL that was only ever meant for a frame. The panels' own
# answers are covered by the service specs.
# Nothing here renders the shell. A request spec that renders the full layout needs a built
# tailwind.css, which CI does not have, so the shell's behaviour is covered where it does not need a
# view: the query budget and the unknown-section fallback both live in
# spec/services/collection_stats/dashboard_spec.rb. Every example below either gets a bare partial
# back (frame requests render no layout), a 404, or a redirect.
RSpec.describe 'CollectionStats', type: :request do
  let(:user) { create(:user, username: 'owner') }
  let!(:collection) { create(:collection, user: user, is_public: true) }
  let(:frame) { { 'Turbo-Frame' => 'stats_panel' } }

  before { create(:collection_magic_card, collection: collection, quantity: 1) }

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
