require "rails_helper"

RSpec.describe EventBatchSchema do
  def event(overrides = {})
    { "type" => "session_start", "occurred_at" => "2026-10-20T14:03:00Z", "app_version" => "1.2.0" }.merge(overrides)
  end

  it "is the schema file at the root of the repository" do
    expect(Rails.root.join("events.schema.json")).to exist
    expect(JSON.parse(Rails.root.join("events.schema.json").read)).to include("title" => "Mini APM event batch")
  end

  it "accepts a batch of every event type" do
    batch = { "events" => [
      event("user_ref" => "u_1", "env" => { "os" => "Windows 11", "ram_mb" => 8192, "gpu" => nil }),
      event("type" => "feature_used", "name" => "export_pdf", "properties" => { "pages" => 3 }),
      event("type" => "error", "message" => "Boom", "stack" => "app.rb:1"),
      event("type" => "crash", "message" => "Boom")
    ] }

    expect(described_class.errors_for(batch)).to be_empty
  end

  it "accepts nulls on the optional fields" do
    batch = { "events" => [ event("user_ref" => nil, "name" => nil, "message" => nil, "stack" => nil, "properties" => nil, "env" => nil) ] }

    expect(described_class.errors_for(batch)).to be_empty
  end

  it "reports each problem under the path of the field, as events.<index>.<field>" do
    batch = { "events" => [ event, event("type" => "crash"), event("app_version" => 1) ] }

    expect(described_class.errors_for(batch).keys).to eq([ "events.1.message", "events.2.app_version" ])
  end

  it "reports a body that is not an object" do
    expect(described_class.errors_for([]).keys).to eq([ "base" ])
    expect(described_class.errors_for(nil).keys).to eq([ "base" ])
  end
end
