Rails.application.routes.draw do
  devise_for :users

  # Superuser-facing puzzle management.
  resources :puzzles do
    collection do
      get :completed # the "Completed" tab on Your stuff — puzzles you've finished
    end
    member do
      patch :publish
      patch :unpublish
      patch :restore # superuser un-tombstones a soft-deleted puzzle
      get :stats
      get :export
    end
  end

  # Tag autocomplete for the authoring combobox — JSON list of existing tag
  # names matching ?q=. Public (creation is public, ADR-0005).
  get "/tags", to: "tags#index", as: :tags

  # Public per-creator page (deferred D3 of ADR-0005): published puzzles + stats.
  get "/u/:handle", to: "users#show", as: :user_page

  # Superuser-only admin: puzzles + users tabs. Gated in Admin::BaseController
  # (404 to everyone else — the area doesn't exist unless you're the superuser).
  namespace :admin do
    root "puzzles#index"
    resources :puzzles, only: :index do
      member { patch :dismiss_reports } # mark a puzzle's flags handled (it's fine)
    end
    resources :users, only: %i[index update] # update = change a user's role
    get "analytics", to: "analytics#index" # traffic + funnels (superuser-only)
  end

  # Public play surface — no login. Browse published puzzles, open one by its
  # unguessable share token.
  get "/play", to: "play#index", as: :play_index
  get "/p/:share_token", to: "play#show", as: :play
  # The game posts a finished play here for stats (anonymous, cookie-attributed).
  post "/p/:share_token/attempts", to: "attempts#create", as: :play_attempts
  # Post-play quality/difficulty rating — updates the viewer's attempt.
  patch "/p/:share_token/rating", to: "ratings#update", as: :play_rating
  # And beacons game_started here on the first tile tap, so we can tell a started-
  # but-abandoned game from one that was only ever opened.
  post "/p/:share_token/events", to: "events#create", as: :play_events
  # Flag a puzzle for staff review (spam/offensive/broken).
  post "/p/:share_token/reports", to: "reports#create", as: :play_reports

  # Public homepage — a launchpad with a random jump-in strip of published
  # puzzles, no login (ADR-0014). Your dashboard lives at /puzzles.
  root "home#show"

  # XML sitemap for search + AI-citation crawlers (public/indexable URLs only).
  get "/sitemap.xml", to: "sitemap#index", defaults: { format: "xml" }, as: :sitemap

  # Living style guide for the brutalist visual system. Public but intentionally
  # unlinked — a dev/design reference, reachable only by typing the URL.
  get "/styleguide", to: "styleguide#show"

  # Static info pages — public, login-free. Linked from the site footer.
  get "/privacy", to: "pages#privacy", as: :privacy
  get "/how-to-play", to: "pages#how_to_play", as: :how_to_play
  get "/making-quartets", to: "pages#making_quartets", as: :making_quartets
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA manifest so the site installs as a standalone home-screen app (linked in
  # the layout head). No service worker — we're not doing offline/caching.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  # root "posts#index"
end
