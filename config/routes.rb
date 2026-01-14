Rails.application.routes.draw do
  get '/auth/:provider/callback', to: 'sessions#create'
  get '/auth/failure', to: 'sessions#failure'
  delete '/logout', to: 'sessions#destroy'
  
  get 'profile', to: 'users#edit'
  patch 'profile', to: 'users#update'

  resources :orders, only: [:index, :create, :show]

  # Dev-only sign-in to ease testing and local dev (available only in dev & test)
  if Rails.env.development? || Rails.env.test?
    post 'dev_login', to: 'dev_sessions#create'
  end
  resources :products
  resources :projects do
    resources :devlogs
  end
  resources :leaderboards, only: [:index]

  namespace :admin do
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
  
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
end
