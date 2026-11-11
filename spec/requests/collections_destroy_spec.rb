require 'rails_helper'

# Only the confirm partial renders here, never a layout: CI has no built tailwind.css.
RSpec.describe 'Collections destroy', type: :request do
  let(:user) { create(:user) }
  let!(:collection) { create(:collection, user: user, name: 'Trade Binder', collection_type: 'binder') }

  def log_in(as)
    post login_path, params: { email: as.email, password: 'password123' }
  end

  describe 'GET confirm_destroy' do
    it 'renders the confirm modal into the frame that asked for it' do
      log_in(user)

      get confirm_destroy_collection_path(collection), headers: { 'Turbo-Frame' => 'collection_modal' }

      expect(response.body).to include('id="collection_modal"', 'Delete Collection', 'Trade Binder')
    end

    it 'names a deck a deck' do
      deck = create(:collection, user: user, collection_type: 'commander_deck')
      log_in(user)

      get confirm_destroy_collection_path(deck), headers: { 'Turbo-Frame' => 'deck_modal' }

      expect(response.body).to include('Delete Deck')
    end
  end

  describe 'DELETE destroy' do
    it 'queues the collection for deletion' do
      log_in(user)

      expect do
        delete collection_path(collection), headers: { 'Turbo-Frame' => 'collection_modal' },
                                            as: :turbo_stream
      end.to have_enqueued_job(DestroyCollectionJob).with(collection.id, user.id)
    end

    it 'hides the card straight away, every copy of it' do
      log_in(user)

      delete collection_path(collection), headers: { 'Turbo-Frame' => 'collection_modal' }, as: :turbo_stream

      expect(response.body).to include('action="remove"', %(targets="#collection_card_#{collection.id}"))
    end

    it 'redraws the decks index without the deck when deleted from there' do
      keep = create(:collection, user: user, name: 'Keeper Deck', collection_type: 'commander_deck')
      gone = create(:collection, user: user, name: 'Doomed Deck', collection_type: 'commander_deck')
      log_in(user)

      delete collection_path(gone, from: 'decks', sort: 'name_asc', group_by: 'none'),
             headers: { 'Turbo-Frame' => 'deck_modal' }, as: :turbo_stream

      expect(response.body).to include('target="deck_groups"', "collection_card_#{keep.id}")
      expect(response.body).not_to include("collection_card_#{gone.id}")
    end

    it 'carries the index view state into the confirm button' do
      deck = create(:collection, user: user, collection_type: 'commander_deck')
      log_in(user)

      get confirm_destroy_collection_path(deck, from: 'decks', sort: 'name_asc', group_by: 'tag'),
          headers: { 'Turbo-Frame' => 'deck_modal' }

      expect(response.body).to include('from=decks', 'sort=name_asc', 'group_by=tag')
    end

    it "will not delete somebody else's collection" do
      stranger = create(:user)
      log_in(stranger)

      expect { delete collection_path(collection), as: :turbo_stream }.not_to have_enqueued_job(DestroyCollectionJob)
      expect(response).to redirect_to(root_path)
    end
  end
end
