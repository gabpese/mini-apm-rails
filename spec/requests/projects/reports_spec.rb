require "rails_helper"

RSpec.describe "Project reports", type: :request do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user, min_ram_mb: 8192, min_os: "Windows 10") }

  before { sign_in user }

  # Gives each version 100 sessions and the given number of crashes, yesterday.
  def seed_versions(crashes_by_version)
    crashes_by_version.each do |version, crashes|
      create_list(:app_session, 100, project: project, app_version: version, started_at: 1.day.ago)
      create_list(:event, crashes, :crash, project: project, app_version: version, occurred_at: 1.day.ago)
    end
  end

  describe "overview" do
    it "shows the totals, a daily series, features and the environment" do
      create_list(:app_session, 3, project: project, started_at: 1.day.ago, ram_mb: 4096)
      create_list(:event, 2, project: project, name: "export_pdf", occurred_at: 1.day.ago)

      get project_path(project)

      expect(response).to have_http_status(:ok)
      expect_inertia.to render_component("projects/show")
      props = inertia.props
      expect(props[:project]).to eq("id" => project.id, "name" => project.name)
      expect(props).to include(days: 30, periods: [ 7, 30, 90 ], regression: nil, min_ram_mb: 8192, min_os: "Windows 10")
      expect(props[:totals]).to include(sessions: 3)
      expect(props[:daily].size).to eq(30)
      expect(props[:features]).to eq([ { "name" => "export_pdf", "uses" => 2 } ])
      expect(props[:environment]).to include(users: 1, below_ram: 1)
      expect(props[:environment][:os]).to be_present
    end

    it "limits the overview to the chosen period" do
      create(:app_session, project: project, started_at: 2.days.ago)
      create(:app_session, project: project, started_at: 20.days.ago)

      get project_path(project, days: 7)
      expect(inertia.props).to include(days: 7)
      expect(inertia.props[:totals]).to include(sessions: 1)
      expect(inertia.props[:daily].size).to eq(7)

      get project_path(project, days: 90)
      expect(inertia.props[:totals]).to include(sessions: 2)
    end

    it "falls back to 30 days for an unsupported period" do
      [ 5, 0, "abc", -7 ].each do |days|
        get project_path(project, days: days)

        expect(inertia.props).to include(days: 30)
      end
    end

    it "shows the regression of the newest version" do
      seed_versions("1.0.0" => 1, "1.1.0" => 20)

      get project_path(project)

      expect(inertia.props[:regression]).to include(version: "1.1.0", previous_version: "1.0.0", ratio: 20.0)
    end

    it "serialises the alert thresholds as numbers, not strings" do
      get project_versions_path(project)

      expect(inertia.props[:thresholds]).to eq("ratio" => 2.0, "min_sessions" => 50)
    end
  end

  describe "versions" do
    it "lists the versions oldest first with the regression of the newest" do
      seed_versions("1.0.0" => 1, "1.1.0" => 20)

      get project_versions_path(project)

      expect(response).to have_http_status(:ok)
      expect_inertia.to render_component("projects/versions/index")
      props = inertia.props
      expect(props[:versions].pluck(:version)).to eq(%w[1.0.0 1.1.0])
      expect(props[:versions].first[:regression]).to be_nil
      expect(props[:versions].last[:regression]).to include(previous_version: "1.0.0")
      expect(props[:regression]).to include(version: "1.1.0")
      expect(props[:adoption][:versions]).to eq(%w[1.0.0 1.1.0])
      expect(props[:adoption][:rows].size).to eq(30)
    end

    it "does not alert about a regression that the newest version already fixed" do
      seed_versions("1.0.0" => 1, "1.1.0" => 20, "1.2.0" => 1)

      get project_versions_path(project)

      expect(inertia.props[:regression]).to be_nil
      expect(inertia.props[:versions].second[:regression]).to include(previous_version: "1.0.0") # still shown as history
    end
  end

  describe "errors" do
    it "lists the error groups of the period" do
      group = create(:error_group, project: project, message: "Boom")
      create_list(:event, 2, :error, project: project, error_group: group, occurred_at: 1.day.ago)

      get project_errors_path(project)

      expect(response).to have_http_status(:ok)
      expect_inertia.to render_component("projects/errors/index")
      expect(inertia.props[:groups].size).to eq(1)
      expect(inertia.props[:groups].first).to include(message: "Boom", occurrences: 2, crashes: 0)
    end

    it "leaves out groups with no occurrence in the period" do
      group = create(:error_group, project: project)
      create(:event, :error, project: project, error_group: group, occurred_at: 40.days.ago)

      get project_errors_path(project)

      expect(inertia.props[:groups]).to be_empty
    end
  end
end
