require "rails_helper"

RSpec.describe DemoDataGenerator do
  let(:until_time) { Time.utc(2026, 10, 20, 15, 0, 0) }

  def generate(**options)
    described_class.new(until_time: until_time, **options).generate
  end

  it "generates the same data for the same seed, and different data for another" do
    expect(generate(days: 5, users: 30, seed: 7)).to eq(generate(days: 5, users: 30, seed: 7))
    expect(generate(days: 5, users: 30, seed: 7)).not_to eq(generate(days: 5, users: 30, seed: 8))
  end

  it "builds events in the API batch format, oldest first" do
    events = generate

    expect(events).to be_present
    expect(events.pluck("type").uniq).to match_array(Event::TYPES)
    expect(events.pluck("occurred_at")).to eq(events.pluck("occurred_at").sort)
    expect(events.each_slice(100).map { |batch| EventBatchSchema.errors_for("events" => batch) }).to all(be_empty)
  end

  it "never generates events after the moment it runs" do
    early = Time.utc(2026, 10, 20, 4, 30)

    events = described_class.new(days: 5, users: 40, until_time: early).generate

    expect(events).not_to be_empty
    expect(events.map { |event| Time.iso8601(event["occurred_at"]) }).to all(be <= early)
  end

  it "fills today too, so the last point of a chart does not fall to zero" do
    early = Time.utc(2026, 10, 20, 5, 15)

    per_day = described_class.new(days: 10, users: 150, until_time: early).generate
      .select { |event| event["type"] == "session_start" }
      .group_by { |event| event["occurred_at"].first(10) }
      .transform_values(&:size)

    expect(per_day.fetch("2026-10-20")).to be > per_day.fetch("2026-10-19") * 0.5
  end

  it "makes the newest version crash at least twice as often as the previous one" do
    events = generate(days: 30, users: 150)

    rate = lambda do |version|
      sessions = events.count { |event| event["type"] == "session_start" && event["app_version"] == version }
      crashes = events.count { |event| event["type"] == "crash" && event["app_version"] == version }
      crashes.fdiv(sessions)
    end

    expect(rate.call("1.2.0")).to be >= 2 * rate.call("1.1.0")
  end

  it "ships the three versions" do
    versions = generate.select { |event| event["type"] == "session_start" }.pluck("app_version").uniq

    expect(versions.sort).to eq(described_class::VERSIONS)
  end
end
