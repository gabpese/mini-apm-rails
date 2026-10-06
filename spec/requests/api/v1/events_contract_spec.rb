require "rails_helper"

# events.schema.json describes a batch of events. The same file, and the same
# list of cases below, live in the Laravel implementation (mini-apm-laravel), so
# the two APIs are held to one contract: for every case the schema and this API
# must give the same verdict.
RSpec.describe "Events API contract", type: :request do
  def schema_event(overrides = {})
    { "type" => "session_start", "occurred_at" => "2026-10-20T14:03:00Z", "app_version" => "1.2.0" }.merge(overrides)
  end

  def schema_batch(*events)
    { "events" => events }
  end

  # Each case is [ name, valid, payload ].
  def self.cases
    [
      [ "a minimal session", true, -> { schema_batch(schema_event) } ],
      [ "every event type", true, -> {
        schema_batch(
          schema_event("user_ref" => "u_1", "env" => { "os" => "Windows 11", "ram_mb" => 8192, "gpu" => "GTX 1660" }),
          schema_event("type" => "feature_used", "name" => "export_pdf", "properties" => { "pages" => 3 }),
          schema_event("type" => "error", "message" => "Boom", "stack" => "app.rb:1"),
          schema_event("type" => "crash", "message" => "Boom")
        )
      } ],
      [ "nulls on the optional fields", true, -> {
        schema_batch(schema_event("user_ref" => nil, "name" => nil, "message" => nil, "stack" => nil, "properties" => nil, "env" => nil))
      } ],
      [ "a date with an offset", true, -> { schema_batch(schema_event("occurred_at" => "2026-10-20T11:03:00-03:00")) } ],
      [ "exactly 100 events", true, -> { { "events" => Array.new(100) { schema_event } } } ],

      [ "no events key", false, -> { {} } ],
      [ "an empty batch", false, -> { { "events" => [] } } ],
      [ "more than 100 events", false, -> { { "events" => Array.new(101) { schema_event } } } ],
      [ "an unknown type", false, -> { schema_batch(schema_event("type" => "bogus")) } ],
      [ "no type", false, -> { schema_batch({ "occurred_at" => "2026-10-20T14:03:00Z", "app_version" => "1.0.0" }) } ],
      [ "no occurred_at", false, -> { schema_batch({ "type" => "session_start", "app_version" => "1.0.0" }) } ],
      [ "no app_version", false, -> { schema_batch({ "type" => "session_start", "occurred_at" => "2026-10-20T14:03:00Z" }) } ],
      [ "a version over 32 characters", false, -> { schema_batch(schema_event("app_version" => "1" * 33)) } ],
      [ "a feature without a name", false, -> { schema_batch(schema_event("type" => "feature_used")) } ],
      [ "a feature with a blank name", false, -> { schema_batch(schema_event("type" => "feature_used", "name" => "  ")) } ],
      [ "a crash without a message", false, -> { schema_batch(schema_event("type" => "crash")) } ],
      [ "an error with an empty message", false, -> { schema_batch(schema_event("type" => "error", "message" => "")) } ],
      [ "a message over 2000 characters", false, -> { schema_batch(schema_event("type" => "error", "message" => "x" * 2001)) } ],
      [ "a negative amount of memory", false, -> { schema_batch(schema_event("env" => { "ram_mb" => -1 })) } ],
      [ "an environment that is not an object", false, -> { schema_batch(schema_event("env" => "Windows")) } ],
      [ "a user_ref that is not text", false, -> { schema_batch(schema_event("user_ref" => 42)) } ]
    ]
  end

  before { Rails.cache.clear }

  cases.each do |name, valid, payload|
    it "gives the same verdict as the schema for #{name}" do
      _, key = ApiKey.generate(create(:project))
      body = instance_exec(&payload)

      expect(EventBatchSchema.errors_for(body).empty?).to be(valid)

      post_events(body, { "Authorization" => "Bearer #{key}" })
      expect(response).to have_http_status(valid ? :accepted : :unprocessable_content)
    end
  end
end
