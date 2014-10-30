Rails.application.routes.draw do
  root :to => 'home#index'

  resources :connectors do
    member do
      get 'reflect'
      get 'reflect/*path' => 'connectors#reflect'
    end
  end

end
