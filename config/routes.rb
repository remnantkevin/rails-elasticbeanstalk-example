Rails.application.routes.draw do
  root "articles#index"
  
  resources :articles

  # Mount the engine in your config/routes.rb file. The following will mount it at http://example.com/good_job.
  # For more info, see https://github.com/bensheldon/good_job#dashboard
  mount GoodJob::Engine => 'good_job'
end
