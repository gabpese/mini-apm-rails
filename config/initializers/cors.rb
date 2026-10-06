# The ingestion API is called from the monitored apps, wherever they run. It
# authenticates with an API key and not with cookies, so any origin is allowed.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"

    resource "/api/*",
      headers: :any,
      methods: [ :post, :options ],
      expose: [ "Retry-After" ],
      max_age: 86_400
  end
end
