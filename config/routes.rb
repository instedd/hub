require 'resque/server'
require 'resque/scheduler/server'

Rails.application.routes.draw do
  devise_for :users, controllers: {omniauth_callbacks: "omniauth_callbacks"}
  guisso_for :user
  root :to => 'home#index'

  get 'angular/*path' => 'home#angular_template'

  resources :connectors do
    member do
      get 'reflect'
      get 'reflect/*path' => 'connectors#reflect', as: 'reflect_with_path'
      get 'data' => 'connectors#query'
      get 'data/*path' => 'connectors#query', as: 'query_with_path'

      post 'invoke/*path' => 'connectors#invoke'
    end
  end

  post 'callback/:connector' => 'callbacks#execute'

  resources :event_handlers

  mount Resque::Server.new, at: '/_resque', constraints: { ip: '127.0.0.1' }
end
