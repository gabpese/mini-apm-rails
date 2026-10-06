require "rails_helper"

RSpec.describe "POST /api/v1/events" do
  let(:project) { create(:project) }
  let(:keys) { ApiKey.generate(project) }
  let(:api_key) { keys.first }
  let(:plain_key) { keys.last }

  before { Rails.cache.clear }

  describe "authentication" do
    it "rejects a request without a key" do
      post_events({ events: [ session_start ] })

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq("message" => "Invalid or missing API key.")
    end

    it "rejects an unknown key" do
      ingest("apm_unknown", [ session_start ])

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a revoked key and stores nothing" do
      api_key.revoke!

      ingest(plain_key, [ session_start ])

      expect(response).to have_http_status(:unauthorized)
      expect(Event.count).to eq(0)
    end

    it "accepts the key in the X-API-Key header" do
      post_events({ events: [ session_start ] }, { "X-API-Key" => plain_key })

      expect(response).to have_http_status(:accepted)
    end

    it "records when the key was last used" do
      expect { ingest(plain_key, [ session_start ]) }
        .to change { api_key.reload.last_used_at }.from(nil)
    end
  end

  describe "validation" do
    def expect_errors_on(*paths)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].keys).to match_array(paths)
    end

    it "requires at least one event" do
      ingest(plain_key, [])

      expect_errors_on("events")
    end

    it "requires the events key" do
      post_events({}, { "Authorization" => "Bearer #{plain_key}" })

      expect_errors_on("events")
    end

    it "rejects a body that is not valid JSON" do
      post "/api/v1/events", params: "{oops", headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{plain_key}" }

      expect_errors_on("base")
    end

    it "rejects more than 100 events in a batch" do
      ingest(plain_key, Array.new(101) { session_start })

      expect_errors_on("events")
    end

    it "accepts exactly 100 events" do
      ingest(plain_key, Array.new(100) { session_start })

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to eq("accepted" => 100)
    end

    it "rejects an unknown event type" do
      ingest(plain_key, [ session_start(type: "bogus") ])

      expect_errors_on("events.0.type")
    end

    it "requires the common fields" do
      ingest(plain_key, [ { type: "session_start" } ])

      expect_errors_on("events.0.occurred_at", "events.0.app_version")
    end

    it "rejects a date that is not ISO 8601" do
      ingest(plain_key, [ session_start(occurred_at: "yesterday") ])

      expect_errors_on("events.0.occurred_at")
    end

    it "rejects fields over their size limit" do
      ingest(plain_key, [ session_start(app_version: "1" * 33), crash(message: "x" * 2001) ])

      expect_errors_on("events.0.app_version", "events.1.message")
    end

    it "requires a name for feature_used events" do
      ingest(plain_key, [ feature_used(name: nil), feature_used(name: "  ") ])

      expect_errors_on("events.0.name", "events.1.name")
    end

    it "requires a message for error and crash events" do
      ingest(plain_key, [ crash(message: nil), crash(type: "error", message: "") ])

      expect_errors_on("events.0.message", "events.1.message")
    end

    it "validates the environment" do
      ingest(plain_key, [ session_start(env: { ram_mb: -1 }) ])

      expect_errors_on("events.0.env.ram_mb")
    end

    it "stores nothing when any event in the batch is invalid" do
      ingest(plain_key, [ session_start, session_start(type: "bogus") ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(Event.count).to eq(0)
      expect(AppSession.count).to eq(0)
    end

    it "ignores fields it does not know" do
      ingest(plain_key, [ session_start(color: "blue") ])

      expect(response).to have_http_status(:accepted)
    end
  end

  describe "storing events" do
    it "answers 202 and stores a session and its events" do
      ingest(plain_key, [ session_start, feature_used, crash ])

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to eq("accepted" => 3)

      session = AppSession.sole
      expect(session).to have_attributes(project_id: project.id, os: "Windows 11", ram_mb: 16_384, gpu: "GTX 1660", user_ref: "u_8f3a", app_version: "1.2.0")
      expect(Event.count).to eq(3)
      expect(Event.feature_used.sole.name).to eq("export_pdf")
      expect(Event.where(app_session_id: session.id).count).to eq(3)
    end

    it "links events to the session even when the batch is out of order" do
      ingest(plain_key, [ crash, session_start ])

      expect(Event.crash.sole.app_session_id).to eq(AppSession.sole.id)
    end

    it "does not link an event to a session of another version or user" do
      ingest(plain_key, [ session_start, crash(app_version: "1.0.0"), crash(user_ref: "u_other") ])

      expect(response).to have_http_status(:accepted)
      expect(Event.where.not(app_session_id: nil).count).to eq(1)
      expect(Event.crash.where.not(app_session_id: nil)).to be_empty
    end

    it "does not link an event that happened before the session started" do
      ingest(plain_key, [ session_start, crash(occurred_at: "2026-10-20T14:00:00Z") ])

      expect(Event.crash.sole.app_session_id).to be_nil
    end

    it "keeps events without a user_ref unlinked" do
      ingest(plain_key, [ session_start, feature_used(user_ref: nil) ])

      expect(Event.feature_used.sole.app_session_id).to be_nil
    end

    it "keeps the message, stack and properties in the payload" do
      ingest(plain_key, [ crash(properties: { "screen" => "export" }) ])

      expect(Event.sole.payload).to eq(
        "message" => "Undefined method for nil",
        "stack" => "app.rb:10:in `run`\napp.rb:3",
        "properties" => { "screen" => "export" }
      )
    end

    it "stores no payload for an event that has none" do
      ingest(plain_key, [ feature_used ])

      expect(Event.sole.payload).to be_nil
    end

    it "stores the time of the event, not the time of the request" do
      ingest(plain_key, [ feature_used(occurred_at: "2026-10-20T11:05:12-03:00") ])

      expect(Event.sole.occurred_at).to eq(Time.utc(2026, 10, 20, 14, 5, 12))
    end
  end

  describe "grouping errors" do
    it "groups equal errors and counts their occurrences" do
      ingest(plain_key, [
        crash(occurred_at: "2026-10-20T14:07:40Z"),
        crash(occurred_at: "2026-10-21T09:00:00Z", stack: "app.rb:10:in `run`\nother.rb:99"),
        crash(message: "A different error")
      ])

      group = ErrorGroup.find_by!(message: "Undefined method for nil")

      expect(ErrorGroup.count).to eq(2)
      expect(group).to have_attributes(
        occurrences: 2,
        first_seen_at: Time.utc(2026, 10, 20, 14, 7, 40),
        last_seen_at: Time.utc(2026, 10, 21, 9, 0, 0)
      )
      expect(Event.where(error_group_id: group.id).count).to eq(2)
    end

    it "separates errors by their first stack line" do
      ingest(plain_key, [ crash, crash(stack: "other.rb:1") ])

      expect(ErrorGroup.count).to eq(2)
    end

    it "keeps counting occurrences across batches" do
      ingest(plain_key, [ crash ])
      ingest(plain_key, [ crash(occurred_at: "2026-10-19T08:00:00Z") ])

      expect(ErrorGroup.sole).to have_attributes(occurrences: 2, first_seen_at: Time.utc(2026, 10, 19, 8, 0, 0))
    end

    it "groups errors and crashes with the same message and stack together" do
      ingest(plain_key, [ crash, crash(type: "error") ])

      expect(ErrorGroup.sole.occurrences).to eq(2)
    end

    it "does not group feature events" do
      ingest(plain_key, [ feature_used ])

      expect(ErrorGroup.count).to eq(0)
    end
  end

  describe "isolation between projects" do
    it "stores data only for the project that owns the key" do
      other_project = create(:project)
      _, other_key = ApiKey.generate(other_project)

      ingest(other_key, [ session_start, crash ])

      expect(response).to have_http_status(:accepted)
      expect(project.events.count).to eq(0)
      expect(other_project.events.count).to eq(2)
      expect(other_project.error_groups.count).to eq(1)
      expect(other_project.app_sessions.count).to eq(1)
    end

    it "groups the same error separately in each project" do
      other_project = create(:project)
      _, other_key = ApiKey.generate(other_project)

      ingest(plain_key, [ crash ])
      ingest(other_key, [ crash ])

      expect(project.error_groups.sole.occurrences).to eq(1)
      expect(other_project.error_groups.sole.occurrences).to eq(1)
    end

    it "does not link events to the sessions of another project" do
      create(:app_session, project: create(:project), user_ref: "u_8f3a", app_version: "1.2.0")

      ingest(plain_key, [ crash ])

      expect(Event.sole.app_session_id).to be_nil
    end
  end

  describe "CORS" do
    it "answers the preflight request from any origin" do
      options "/api/v1/events", headers: {
        "Origin" => "https://app.example.com",
        "Access-Control-Request-Method" => "POST",
        "Access-Control-Request-Headers" => "authorization,content-type,x-api-key"
      }

      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(response.headers["Access-Control-Allow-Methods"]).to include("POST")
    end

    it "allows any origin on the response" do
      ingest(plain_key, [ session_start ], { "Origin" => "https://app.example.com" })

      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
    end
  end

  describe "rate limiting" do
    it "answers 429 after 120 requests in a minute with the same key" do
      120.times { ingest(plain_key, [ session_start ]) }
      expect(response).to have_http_status(:accepted)

      ingest(plain_key, [ session_start ])

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to eq("60")
      expect(response.parsed_body).to eq("message" => "Too many requests.")
    end

    it "limits invalid keys too" do
      120.times { ingest("apm_unknown", [ session_start ]) }
      expect(response).to have_http_status(:unauthorized)

      ingest("apm_unknown", [ session_start ])

      expect(response).to have_http_status(:too_many_requests)
    end

    it "limits requests without any key" do
      120.times { post_events({ events: [ session_start ] }) }

      post_events({ events: [ session_start ] })

      expect(response).to have_http_status(:too_many_requests)
    end

    it "counts each key apart" do
      120.times { ingest(plain_key, [ session_start ]) }
      _, other_key = ApiKey.generate(create(:project))

      ingest(other_key, [ session_start ])

      expect(response).to have_http_status(:accepted)
    end

    it "answers 429 after 600 requests in a minute from the same IP, whatever the key" do
      600.times { |i| ingest("apm_unknown_#{i}", [ session_start ]) }
      expect(response).to have_http_status(:unauthorized)

      ingest("apm_unknown_next", [ session_start ])

      expect(response).to have_http_status(:too_many_requests)
    end

    it "starts counting again after the minute" do
      120.times { ingest(plain_key, [ session_start ]) }
      ingest(plain_key, [ session_start ])
      expect(response).to have_http_status(:too_many_requests)

      travel_to(61.seconds.from_now) { ingest(plain_key, [ session_start ]) }

      expect(response).to have_http_status(:accepted)
    end
  end
end
