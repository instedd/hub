Rails.application.routes.draw do
  devise_for :users, controllers: {omniauth_callbacks: "omniauth_callbacks"}
  guisso_for :user
  root :to => 'home#index'

  resources :connectors do
    member do
      get 'reflect'
      get 'reflect/*path' => 'connectors#reflect'
    end
  end

end
