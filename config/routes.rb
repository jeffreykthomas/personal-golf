Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resources :users, only: [:new, :create]
  
  # OAuth routes
  get '/auth/:provider', to: lambda { |env|
    # This route is handled by OmniAuth middleware
    [404, {}, ["Not Found"]]
  }, as: :oauth_request
  get '/auth/:provider/callback', to: 'sessions#oauth_create'
  get '/auth/failure', to: 'sessions#oauth_failure'
  
  # Onboarding flow
  namespace :onboarding do
    get :welcome
    get :skill_level
    patch :skill_level, action: :update_skill_level
    get :goals
    patch :goals, action: :update_goals
    get :first_tip
    post :save_first_tip
  end

  # Main app routes
  resources :tips do
    member do
      post :save
      delete :unsave
    end
    collection do
      get :next
      get :saved
      post :request_ai_tips
    end
  end

  resources :categories, only: [:index, :show]

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "onboarding#welcome"
end
