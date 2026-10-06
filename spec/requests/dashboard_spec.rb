require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  describe "GET /dashboard" do
    it "requires login" do
      get dashboard_path

      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in user }

      it "lists only my projects, newest first" do
        old = create(:project, user: user, name: "Old", created_at: 2.days.ago)
        newer = create(:project, user: user, name: "Newer")
        create(:project, name: "Someone else's")

        get dashboard_path

        expect(response).to have_http_status(:ok)
        expect_inertia.to render_component("dashboard/index")
        expect(inertia.props[:projects].pluck(:id)).to eq([ newer.id, old.id ])
        expect(inertia.props[:period]).to eq(30)
      end

      it "summarises each project and marks a regression in the newest version" do
        project = create(:project, user: user)
        { "1.0.0" => 1, "1.1.0" => 20 }.each do |version, crashes|
          create_list(:app_session, 100, project: project, app_version: version, started_at: 1.day.ago)
          create_list(:event, crashes, :crash, project: project, app_version: version, occurred_at: 1.day.ago)
        end

        get dashboard_path

        expect(inertia.props[:projects].first).to include(
          name: project.name, sessions: 200, crashes: 21, latest_version: "1.1.0", regression: true
        )
        expect(inertia.props[:projects].first[:crash_rate]).to be_within(0.0001).of(0.105)
      end

      it "has no latest version for a project without data" do
        create(:project, user: user)

        get dashboard_path

        expect(inertia.props[:projects].first).to include(sessions: 0, latest_version: nil, regression: false)
      end
    end
  end
end
