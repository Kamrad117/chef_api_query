Rails.application.routes.draw do
  root :to => "home#index"
  
  match '/chef_export_csv', to: 'home#export_to_csv', via: :get, as: :chef_csv
  match '/got_error', to: 'home#error', via: :get, as: :error


  devise_for :users, :controllers => {:registrations => "registrations"}
  resources :users
end
