module IngestionHelpers
  def post_events(body, headers = {})
    post "/api/v1/events", params: body.to_json, headers: { "Content-Type" => "application/json" }.merge(headers)
  end

  def ingest(key, events, headers = {})
    post_events({ events: events }, { "Authorization" => "Bearer #{key}" }.merge(headers))
  end

  def session_start(overrides = {})
    {
      type: "session_start",
      occurred_at: "2026-10-20T14:03:00Z",
      app_version: "1.2.0",
      user_ref: "u_8f3a",
      env: { os: "Windows 11", ram_mb: 16_384, gpu: "GTX 1660" }
    }.merge(overrides)
  end

  def feature_used(overrides = {})
    {
      type: "feature_used",
      name: "export_pdf",
      occurred_at: "2026-10-20T14:05:12Z",
      app_version: "1.2.0",
      user_ref: "u_8f3a"
    }.merge(overrides)
  end

  def crash(overrides = {})
    {
      type: "crash",
      occurred_at: "2026-10-20T14:07:40Z",
      app_version: "1.2.0",
      user_ref: "u_8f3a",
      message: "Undefined method for nil",
      stack: "app.rb:10:in `run`\napp.rb:3"
    }.merge(overrides)
  end
end

RSpec.configure do |config|
  config.include IngestionHelpers, type: :request
end
