require "rails_helper"

RSpec.describe AppSession do
  describe ".latest_for" do
    let(:project) { create(:project) }

    def start(at, **attrs)
      create(:app_session, project: project, started_at: Time.zone.parse(at), **attrs)
    end

    it "returns the latest session that had started by the given time" do
      start("2026-10-20T10:00:00Z")
      latest = start("2026-10-20T12:00:00Z")
      start("2026-10-20T16:00:00Z")

      found = project.app_sessions.latest_for(user_ref: "u_8f3a", app_version: "1.2.0", at: Time.zone.parse("2026-10-20T14:00:00Z"))

      expect(found).to eq(latest)
    end

    it "ignores other users and versions" do
      start("2026-10-20T10:00:00Z", user_ref: "u_other")
      start("2026-10-20T10:00:00Z", app_version: "1.0.0")

      found = project.app_sessions.latest_for(user_ref: "u_8f3a", app_version: "1.2.0", at: Time.zone.parse("2026-10-20T14:00:00Z"))

      expect(found).to be_nil
    end
  end
end
