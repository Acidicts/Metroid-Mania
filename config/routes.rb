Rails.application.routes.draw do
  # wishlist_items feature removed; routes cleaned up
  # users interact with wishlists via custom member actions for adding/removing
  # products.  The helper names are intentionally descriptive so views can
  # remain readable.
  resources :wishlists do
    member do
      post :add_product
      post :remove_product
    end
  end
  # basic CRUD paths for community goals (only index/new/edit actions
  # exist at the moment; more can be added later).  Using `resources` ensures
  # the usual path helpers such as `goals_path` are available.
  resources :goals, only: [ :index, :new, :edit ] do
    collection do
      post :award
      post :force_award
    end
  end
  resources :achievements
  resources :charm_notches do
    # allow users to donate an un‑slotted charm notch to another user. this
    # is not tied to a specific notch record, so the route lives on the
    # collection. the helper takes a user argument so the profile button can
    # simply pass `@user`.
    post :donate, on: :collection, path: "donate/:user_id", as: "donate"
  end
  # legacy path used by older clients; redirect to index to avoid hitting
  # the show action with id = "loadout".
  get "charm_slots/loadout", to: redirect("/charm_slots")

  resources :charm_slots do
    collection do
      # submit a user's pending slots (loadout) for processing
      post :submit
    end
    member do
      # detach a slot from its order and clear any attached notches
      patch :remove
      # support GET for clients that can't do PATCH (older browsers, crawlers)
      get :remove
    end
  end
  resources :assets_items do
    resources :spritesheets, only: [ :show, :new, :create, :edit, :update, :destroy ] do
      get :download, on: :member
    end
  end
  resources :assets_projects do
    resources :assets_items, only: [ :new, :create ] do
      resources :spritesheets, only: [ :show, :new, :create, :edit, :update, :destroy ] do
        get :download, on: :member
      end
    end
  end
  resources :comments
  get "metroidmania/index"
  get "shared/_retro_sample"
  get "/auth/:provider/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"

  get "/leaderboard", to: "leaderboards#index"

  # primary logout route: support DELETE for normal operation and GET as a safe fallback
  # some clients (e.g. crawlers or users with JS disabled) may issue a GET, so
  # we handle both methods rather than raising a routing error.
  match "/logout", to: "sessions#destroy", via: [ :delete, :get ]

  get "profile", to: "users#edit"
  patch "profile", to: "users#update"
  get "users/:id", to: "users#show", as: "user_profile"

  # allow users to cancel or otherwise modify their own orders via PUT/PATCH
  resources :orders, only: [ :index, :new, :create, :show, :update ]

  # Dev-only sign-in to ease testing and local dev (available only in dev & test)
  if Rails.env.development? || Rails.env.test?
    post "dev_login", to: "dev_sessions#create"
  end
  resources :products
  resources :projects do
    member do
      post :like
      post :unlike
      # graceful fallback when JS is unavailable or link is accessed directly.
      get :like, to: redirect("/projects/%{id}")
      get :unlike, to: redirect("/projects/%{id}")
    end

    resources :devlogs
    resources :ship_requests, only: [ :new, :create, :show, :index ]
  end
  resources :leaderboards, only: [ :index ]

  namespace :admin do
    # use a resourceful route so path helpers like `admin_project_tags_path` are defined
    resources :project_tags
    resources :sales

    root to: "dashboard#index"
    get "dashboard", to: "dashboard#index"
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    resources :users do
      member do
        post :revert_actions
      end
    end
    resources :orders, only: [ :index, :show ] do
      member do
        post :fulfill
        post :decline
        post :delete
        post :pend
        post :update_status
        post :dm
      end
    end
    resources :projects do
      member do
        post :approve
        post :reject
        post :ship
        post :unship
        post :force_ship
        post :set_status
        # Allow admins to delete via POST to avoid relying on method-override/javascript
        post :delete, action: :destroy
      end
    end

    resources :ship_requests, only: [ :index, :show ] do
      member do
        post :approve
        post :reject
      end
    end

    resources :ships, only: [ :index, :show, :edit, :update ]

    post "projects/bulk_update", to: "projects_bulk#create", as: "bulk_update_admin_projects"

    resources :audits, only: [ :index ]

    resources :achievements
    post "cdn_upload", to: "cdn_uploads#create"

    # Site settings (feature toggles)
    get "site_settings", to: "site_settings#index"
    patch "site_settings", to: "site_settings#update"
  end

  # Allow project owners to ship their own project
  resources :projects, only: [] do
    member do
      post :ship, to: "projects#ship"
    end
  end

  get "home/index"
  get "home" => "home#index"

  get "gallery/index"
  get "gallery" => "gallery#index"

  # Local-only preview route for the shared retro sample partial
  get "/shared/_retro_sample", to: "shared#_retro_sample" if Rails.env.development? || Rails.env.test?

  get "up" => "rails/health#show", as: :rails_health_check

  # ensure a named helper exists for logout and that it accepts DELETE (and GET via
  # the primary route above). we guard against redefinition in case some other
  # segment of the app already set up a logout path.
  begin
    unless Rails.application.routes.named_routes.key?(:logout)
      # the `match` above already defines both methods; specify as a helper here too.
      match "/logout", to: "sessions#destroy", via: [ :delete, :get ], as: :logout
    end
  rescue ArgumentError
    # another route with the same name/path was registered elsewhere — ignore to keep routes loadable
  end

  # previous development-only GET fallback is no longer necessary, since the route
  # already accepts GET in all environments.

  root "home#index"
end
