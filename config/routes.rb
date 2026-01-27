Rails.application.routes.draw do
  # Authentication routes
  get 'sign_up', to: 'users/registrations#new', as: :sign_up
  post 'sign_up', to: 'users/registrations#create', as: :user_registration

  get 'login', to: 'users/sessions#new', as: :login
  post 'login', to: 'users/sessions#create'
  delete 'logout', to: 'users/sessions#destroy', as: :logout

  get 'password_resets/new', to: 'users/password_resets#new', as: :new_password_reset
  post 'password_resets', to: 'users/password_resets#create', as: :password_resets
  get 'password_resets/:token/edit', to: 'users/password_resets#edit', as: :edit_password_reset
  patch 'password_resets/:token', to: 'users/password_resets#update', as: :password_reset

  # Features page
  get 'features', to: 'features#show', as: :features

  # Settings routes
  get 'settings', to: 'settings#show', as: :settings
  post 'settings/move_collection', to: 'settings#move_collection', as: :move_collection
  post 'settings/update_column_visibility', to: 'settings#update_column_visibility', as: :update_column_visibility
  post 'settings/update_game_tracker_visibility', to: 'settings#update_game_tracker_visibility', as: :update_game_tracker_visibility

  mount MissionControl::Jobs::Engine, at: '/jobs'

  namespace :admin do
    resources :tags, except: [:show]
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get 'service-worker' => 'rails/pwa#service_worker', as: :pwa_service_worker
  get 'manifest' => 'rails/pwa#manifest', as: :pwa_manifest

  root 'boxsets#index'

  post 'dashboard/ingest', to: 'dashboard#ingest', as: :dashboard_ingest
  post 'dashboard/ingest_prices', to: 'dashboard#ingest_prices', as: :dashboard_ingest_prices
  post 'dashboard/reset-collection', to: 'dashboard#reset_collections', as: :dashboard_reset_collections
  post 'dashboard/clear-jobs', to: 'dashboard#clear_jobs', as: :dashboard_clear_jobs
  post 'dashboard/backfill-boxset-history', to: 'dashboard#backfill_boxset_history', as: :dashboard_backfill_boxset_history
  post 'dashboard/trim-boxset-history', to: 'dashboard#trim_boxset_history', as: :dashboard_trim_boxset_history
  post 'dashboard/backfill-price-change-weekly', to: 'dashboard#backfill_price_change_weekly', as: :dashboard_backfill_price_change_weekly
  post 'dashboard/backfill-scryfall-oracle-id', to: 'dashboard#backfill_scryfall_oracle_id', as: :dashboard_backfill_scryfall_oracle_id

  get 'load_boxset', to: 'boxsets#load_boxset', as: :load_boxset
  get 'commanders', to: 'commanders#index', as: :commanders
  get 'load_commanders', to: 'commanders#load_commanders', as: :load_commanders
  get 'load_collection', to: 'collections#load', as: :load_collection
  resources :boxsets
  resources :magic_cards

  resources :precon_decks, only: %i[index show], path: 'precon-decks' do
    member do
      post :import_to_collection
    end
  end

  # route for loading collection quantity w/card_details
  get 'collection_magic_cards/quantity', to: 'collection_magic_cards#quantity', as: :collection_quantity
  post 'collection_magic_cards/update_collection', to: 'collection_magic_cards#update_collection', as: :collection_magic_cards_update
  post 'collection_magic_cards/transfer', to: 'collection_magic_cards#transfer', as: :transfer_collection_magic_cards
  post 'collection_magic_cards/adjust', to: 'collection_magic_cards#adjust', as: :adjust_collection_magic_cards
  resources :collection_magic_cards

  get 'boxset_card/:id', to: 'magic_cards#show_boxset_card', as: :boxset_magic_card
  resources :collections, only: %w[new create update] do
    member do
      get :edit_collection_modal
    end
  end
  get 'collections/:username/overview', to: 'collections#overview', as: :collections_overview
  get 'collections/:username(/:collection_id)', to: 'collections#show', as: :collection_show
  # Decks index and show routes
  get 'decks/:username', to: 'decks#index', as: :decks_index
  get 'decks/:username/:collection_id', to: 'collections#show_decks', as: :deck_show

  # Deck builder routes
  resources :deck_builder, path: 'deck-builder', only: [:show] do
    member do
      get :search
      post :add_card
      post :add_new_card
      delete :remove_card
      post :swap_card
      patch :update_quantity
      post :finalize
      patch :set_commander
      patch :remove_commander
      get :confirm_remove_modal
      get :confirm_finalize_modal
      get :edit_deck_modal
      patch :update_deck
      get :transfer_card_modal
      post :transfer_card
      get :swap_printing_modal
      post :swap_printing
      get :choose_printing_modal
      get :swap_source_modal
      post :swap_source
      get :edit_staged_modal
      patch :update_staged
      get :view_card_modal
    end
  end

  # Game tracker routes (username-scoped for public viewing)
  scope 'game-tracker' do
    # Modification routes (always authenticated, no username)
    resources :tracked_decks, path: 'decks', only: %i[new create edit update destroy], controller: 'game_tracker/tracked_decks' do
      collection do
        get :search_commanders
      end
    end

    resources :commander_games, path: 'games', only: %i[new create edit update destroy], controller: 'game_tracker/commander_games' do
      collection do
        get :search_opponents
      end
    end
  end

  # Username-scoped routes for viewing (public if enabled)
  scope 'game-tracker/:username', as: 'game_tracker' do
    get '/', to: 'game_tracker#show', as: ''
    resources :decks, only: %i[index show], controller: 'game_tracker/tracked_decks', as: 'tracked_decks'
    resources :games, only: %i[index show], controller: 'game_tracker/commander_games', as: 'commander_games'
  end

  # Card scanner routes
  get 'scan-cards', to: 'card_scanner#show', as: :card_scanner
  get 'scan-cards/search', to: 'card_scanner#search', as: :card_scanner_search
  post 'scan-cards/add_to_collection', to: 'card_scanner#add_to_collection', as: :card_scanner_add
end
