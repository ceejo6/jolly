Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root to: proc { [200, { "Content-Type" => "text/plain" }, ["Jolly Rails OK\n"]] }
end
