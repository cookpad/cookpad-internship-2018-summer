Rails.application.routes.draw do
  match "/ws", to: ChatApp.new, via: :all

  resources :channels, only: %i(index) do
    resources :messages, only: %i(create)
  end
  resources :images, only: %i(show create)

  namespace :hello do
    resource :health, only: %i(show)
  end
end
