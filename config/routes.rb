Rails.application.routes.draw do
  get "metroidmania/index"
  get "shared/_retro_sample"
  get '/auth/:provider/callback', to: 'sessions#create'
  get '/auth/failure', to: 'sessions#failure'

  get "/leaderboard", to: "leaderboards#index"

  delete '/logout', to: 'sessions#destroy'
  
  get 'profile', to: 'users#edit'
  patch 'profile', to: 'users#update'
  get 'users/:id', to: 'users#show', as: 'user_profile'

  resources :orders, only: [:index, :new, :create, :show]

  # Dev-only sign-in to ease testing and local dev (available only in dev & test)
  if Rails.env.development? || Rails.env.test?
    post 'dev_login', to: 'dev_sessions#create'
  end
  resources :products
  resources :projects do
    resources :devlogs
    resources :ship_requests, only: [:create, :show, :index]
  end
  resources :leaderboards, only: [:index]

  namespace :admin do
    root to: 'dashboard#index'
    get 'dashboard', to: 'dashboard#index'
    get 'login', to: 'sessions#new'
    post 'login', to: 'sessions#create'
    delete 'logout', to: 'sessions#destroy'

    resources :users do
      member do
        post :revert_actions
      end
    end
    resources :orders, only: [:index, :show] do
      member do
        post :fulfill
        post :decline
        post :delete
        post :pend
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
      end
    end

    resources :ship_requests, only: [:index, :show] do
      member do
        post :approve
        post :reject
      end
    end

    resources :ships, only: [:index, :show, :edit, :update]

    post 'projects/bulk_update', to: 'projects_bulk#create', as: 'bulk_update_admin_projects'

    resources :audits, only: [:index]

  end

  # Allow project owners to ship their own project
  resources :projects, only: [] do
    member do
      post :ship, to: 'projects#ship'
    end
  end

  get "home/index"
  get "home" => "home#index"

  # Local-only preview route for the shared retro sample partial
  get "/shared/_retro_sample", to: "shared#_retro_sample" if Rails.env.development? || Rails.env.test?
  
  get "up" => "rails/health#show", as: :rails_health_check

  # Ensure a DELETE /logout exists for link_to(..., method: :delete).
  # Be defensive: if a route or helper named :logout already exists, skip adding to avoid ArgumentError.
  begin
    unless Rails.application.routes.named_routes.key?(:logout)
      delete "/logout", to: "sessions#destroy", as: :logout
    end
  rescue ArgumentError
    # another route with the same name/path was registered elsewhere — ignore to keep routes loadable
  end

  # Development-only GET fallback when JS isn't running — only add if it won't collide
  if Rails.env.development?
    begin
      # add GET fallback only when it won't raise due to duplicate routes
      get "/logout", to: "sessions#destroy" unless Rails.application.routes.recognize_path("/logout", method: :get) rescue true
    rescue ArgumentError, ActionController::RoutingError
      # skip adding fallback if it collides or can't be recognized
    end
  end

  root "home#index"
end
