Rails.application.routes.draw do
  revise_auth
  mount MissionControl::Jobs::Engine, at: "/jobs"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root "dashboard#index"

  post "dashboard/ingest", to: "dashboard#ingest", as: "dashboard_ingest"
  get "load_boxset", to: "boxsets#load_boxset", as: "load_boxset"
  resources :boxsets
  resources :magic_cards
  get "collection_magic_cards/quantity", to: "collection_magic_cards#quantity", as: "collection_quantity"
  post "collection_magic_cards/update_collection", to: "collection_magic_cards#update_collection", as: "collection_magic_cards_update"
  resources :collection_magic_cards
  get "boxset_card/:id", to: "magic_cards#show_boxset_card", as: "boxset_magic_card"
end
