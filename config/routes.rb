Rails.application.routes.draw do
  post 'sign_up', to: 'users/registrations#create', as: :user_registration

  revise_auth
  mount MissionControl::Jobs::Engine, at: '/jobs'

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

  get 'load_boxset', to: 'boxsets#load_boxset', as: :load_boxset
  get 'load_collection', to: 'collections#load', as: :load_collection
  resources :boxsets
  resources :magic_cards

  # route for loading collection quantity w/card_details
  get 'collection_magic_cards/quantity', to: 'collection_magic_cards#quantity', as: :collection_quantity
  post 'collection_magic_cards/update_collection', to: 'collection_magic_cards#update_collection', as: :collection_magic_cards_update
  resources :collection_magic_cards

  get 'boxset_card/:id', to: 'magic_cards#show_boxset_card', as: :boxset_magic_card
  resources :collections, only: %w[new create]
  get 'collections/:username(/:collection_id)', to: 'collections#show', as: :collection_show
end
