Rails.application.routes.draw do
  devise_for :users

  # Superuser-facing puzzle management.
  resources :puzzles do
    member do
      patch :publish
      get :stats
    end
  end

  # Public play surface — no login. Browse published puzzles, open one by its
  # unguessable share token.
  get "/play", to: "play#index", as: :play_index
  get "/p/:share_token", to: "play#show", as: :play
  # The game posts a finished play here for stats (anonymous, cookie-attributed).
  post "/p/:share_token/attempts", to: "attempts#create", as: :play_attempts

  # Public homepage — a random featured puzzle, no login. The admin dashboard
  # lives at /puzzles.
  root "home#show"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
