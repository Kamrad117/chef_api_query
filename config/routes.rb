Rails.application.routes.draw do
  root :to => "home#index"
  match '/qhef_export_csv', to: 'home#export_to_csv', via: :get, as: :chef_csv

  devise_for :users, :controllers => {:registrations => "registrations"}
  resources :users
end
