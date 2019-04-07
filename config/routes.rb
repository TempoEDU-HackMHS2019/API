Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  scope 'v1' do
    post 'create', to: 'api#create_user'
    post 'login', to: 'api#login'
    scope 'event' do
      post 'create', to: 'api#add_event'
      get 'all', to: 'api#get_events'
      delete ':id', to: 'api#delete_event'
      get ':id', to: 'api#get_event'
    end
    get 'profile', to: 'api#profile'
  end
end
