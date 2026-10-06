require "rails_helper"

RSpec.describe ProjectStats do
  let(:project) { create(:project, min_ram_mb: 8192, min_os: "Windows 10") }
  let(:stats) { described_class.new(project, days: 7) }
  let(:yesterday) { 1.day.ago }

  def session(**attributes)
    create(:app_session, **{
      project: project, user_ref: "u_a", app_version: "1.0.0", os: "Windows 11",
      ram_mb: 16_384, gpu: "RTX 3060", started_at: yesterday
    }.merge(attributes))
  end

  def event(type, **attributes)
    create(:event, **{
      project: project, event_type: type, name: (type == "feature_used" ? "export_pdf" : nil),
      app_version: "1.0.0", occurred_at: yesterday,
      payload: (%w[error crash].include?(type) ? { "message" => "Boom" } : nil)
    }.merge(attributes))
  end

  describe "#since" do
    it "is the start of the first day of a period that ends today" do
      travel_to(Time.utc(2026, 10, 20, 15, 30)) do
        expect(stats.since).to eq(Time.utc(2026, 10, 14))
      end
    end
  end

  describe "#totals" do
    it "counts sessions, users, errors and crashes in the period" do
      session
      session(user_ref: "u_a")
      session(user_ref: "u_b")
      session(started_at: 20.days.ago) # outside the period
      event("error")
      event("crash")
      event("crash", occurred_at: 20.days.ago)

      expect(stats.totals).to eq(sessions: 3, users: 2, errors: 1, crashes: 1, crash_rate: 1 / 3.0)
    end

    it "does not count another project" do
      other = create(:project)
      session(project: other)
      event("crash", project: other)

      expect(stats.totals).to include(sessions: 0, crashes: 0, crash_rate: 0.0)
    end
  end

  describe "#daily" do
    it "gives one row per day, with zeros on quiet days" do
      session(started_at: 2.days.ago)
      session(started_at: 2.days.ago)
      event("crash", occurred_at: 2.days.ago)
      event("error", occurred_at: Time.current)

      daily = stats.daily.index_by { |row| row[:date] }

      expect(daily.size).to eq(7)
      expect(daily[2.days.ago.to_date.iso8601]).to include(sessions: 2, crashes: 1, errors: 0)
      expect(daily[Date.current.iso8601]).to include(sessions: 0, crashes: 0, errors: 1)
      expect(daily[5.days.ago.to_date.iso8601]).to include(sessions: 0, crashes: 0, errors: 0)
    end
  end

  describe "#top_features" do
    it "ranks the most used features in the period" do
      %w[a a a b b c].each { |name| event("feature_used", name: name) }
      event("feature_used", name: "old", occurred_at: 30.days.ago)

      expect(stats.top_features(2)).to eq([ { name: "a", uses: 3 }, { name: "b", uses: 2 } ])
    end
  end

  describe "#error_groups" do
    it "lists the groups by occurrences in the period" do
      busy = create(:error_group, project: project, message: "busy", fingerprint: "busy")
      quiet = create(:error_group, project: project, message: "quiet", fingerprint: "quiet")
      old = create(:error_group, project: project, message: "old", fingerprint: "old")

      3.times { event("error", error_group: busy) }
      event("crash", error_group: busy)
      event("error", error_group: quiet)
      event("error", error_group: old, occurred_at: 30.days.ago)

      groups = stats.error_groups

      expect(groups.pluck(:message)).to eq(%w[busy quiet])
      expect(groups.first).to include(id: busy.id, occurrences: 4, crashes: 1)
      expect(groups.first[:first_seen_at]).to match(/\A\d{4}-\d\d-\d\dT/)
    end

    it "does not list the groups of another project" do
      other = create(:project)
      group = create(:error_group, project: other)
      event("error", error_group: group, project: other)

      expect(stats.error_groups).to be_empty
    end
  end

  describe "#versions" do
    before do
      100.times do |i|
        session(app_version: "1.9.0", user_ref: "u_#{i}")
        session(app_version: "1.10.0", user_ref: "u_#{i}")
      end
      event("crash", app_version: "1.9.0")
      10.times { event("crash", app_version: "1.10.0") }
    end

    it "summarises versions oldest first and flags a regression" do
      versions = stats.versions

      expect(versions.pluck(:version)).to eq(%w[1.9.0 1.10.0])
      expect(versions.first).to include(sessions: 100, users: 100, crashes: 1, regression: nil)
      expect(versions.last[:regression]).to include(previous_version: "1.9.0", ratio: 10.0)
    end

    it "covers the whole life of the project, not only the period" do
      session(app_version: "0.9.0", started_at: 200.days.ago)

      expect(stats.versions.pluck(:version)).to eq(%w[0.9.0 1.9.0 1.10.0])
    end

    it "reports the regression of the newest version" do
      expect(stats.latest_regression).to include(version: "1.10.0", previous_version: "1.9.0", ratio: 10.0, crash_rate: 0.1)
    end
  end

  describe "#latest_regression" do
    it "is nil when the newest version has none, even if an older one was flagged" do
      { "1.0.0" => 1, "1.1.0" => 20, "1.2.0" => 1 }.each do |version, crashes|
        100.times { |i| session(app_version: version, user_ref: "u_#{i}") }
        crashes.times { event("crash", app_version: version) }
      end

      expect(stats.versions.second[:regression]).to be_present
      expect(stats.latest_regression).to be_nil
    end

    it "is nil without any version" do
      expect(stats.latest_regression).to be_nil
    end
  end

  describe "#adoption" do
    it "shows sessions by day and version" do
      session(app_version: "1.0.0", started_at: 3.days.ago)
      2.times { session(app_version: "1.1.0", started_at: 1.day.ago) }

      adoption = stats.adoption
      rows = adoption[:rows].index_by { |row| row["date"] }

      expect(adoption[:versions]).to eq(%w[1.0.0 1.1.0])
      expect(rows.size).to eq(7)
      expect(rows[3.days.ago.to_date.iso8601]).to include("1.0.0" => 1, "1.1.0" => 0)
      expect(rows[1.day.ago.to_date.iso8601]).to include("1.0.0" => 0, "1.1.0" => 2)
    end
  end

  describe "#environment" do
    it "finds machines below the minimum requirements" do
      session(user_ref: "ok", os: "Windows 11", ram_mb: 16_384)
      session(user_ref: "ok", os: "Windows 11", ram_mb: 16_384)
      session(user_ref: "low_ram", os: "Windows 11", ram_mb: 4096)
      session(user_ref: "old_os", os: "Windows 7", ram_mb: 16_384)
      session(user_ref: "both", os: "Windows 7", ram_mb: 2048)
      session(user_ref: "mac", os: "macOS 14", ram_mb: 16_384)

      expect(stats.environment).to include(users: 5, below_minimum: 3, below_ram: 2, below_os: 2)
    end

    it "groups the machines and folds the long tail into Other" do
      (1..9).each { |i| session(user_ref: "u_#{i}", gpu: "GPU #{i}") }
      session(user_ref: "u_1", gpu: "GPU 1")

      environment = stats.environment

      expect(environment[:gpu].size).to eq(9)
      expect(environment[:gpu].last).to eq(label: "Other", users: 1)
      expect(environment[:ram]).to eq([ { label: "16 GB", users: 9 } ])
    end

    it "labels missing data as Unknown" do
      session(os: nil, ram_mb: nil, gpu: nil)

      expect(stats.environment).to include(
        os: [ { label: "Unknown", users: 1 } ],
        ram: [ { label: "Unknown", users: 1 } ],
        gpu: [ { label: "Unknown", users: 1 } ]
      )
    end

    it "treats a missing minimum as nothing to check" do
      lenient = create(:project, min_ram_mb: nil, min_os: nil)
      session(ram_mb: 512, os: "Windows 7", project: lenient)

      expect(described_class.new(lenient, days: 7).environment).to include(below_minimum: 0)
    end
  end
end
