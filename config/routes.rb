Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"
  get "data", to: "pages#data", as: :data_page
  get "analyse", to: "pages#analyse", as: :analyse_page
  get "oil-gold", to: "pages#oil_gold", as: :oil_gold_page
  post "ingestion/:source", to: "pages#run_ingestion", as: :run_ingestion
  get "ingestion_runs/:id/log", to: "pages#run_log", as: :run_log
  delete "ingestion_runs/:id", to: "pages#delete_run", as: :delete_run
  delete "ingestion_runs/:id/data", to: "pages#delete_run_data", as: :delete_run_data
  delete "ingestion_runs/cleanup", to: "pages#cleanup_runs", as: :cleanup_runs
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
