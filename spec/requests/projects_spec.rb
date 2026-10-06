require "rails_helper"

RSpec.describe "Projects", type: :request do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user, min_ram_mb: 8192, min_os: "Windows 10") }

  before { sign_in user }

  describe "POST /projects" do
    it "creates the project with a first API key, shown once on the settings page" do
      post projects_path, params: { name: "My app", min_ram_mb: 4096, min_os: "Windows 10" }

      created = user.projects.sole
      expect(created).to have_attributes(name: "My app", min_ram_mb: 4096, min_os: "Windows 10")
      expect(response).to redirect_to(edit_project_path(created))

      follow_redirect!
      expect_inertia.to render_component("projects/edit")
      expect(inertia.flash[:new_key]).to include(name: "Default", key: /\Aapm_\w{40}\z/)
      expect(inertia.props[:keys].size).to eq(1)

      get edit_project_path(created)
      expect(inertia.flash[:new_key]).to be_nil
    end

    it "stores only the digest of the first key" do
      post projects_path, params: { name: "My app" }

      key = user.projects.sole.api_keys.sole
      expect(key.key_hash).to match(/\A\h{64}\z/)
      expect(key.key_prefix).to start_with("apm_")
    end

    it "validates the fields" do
      post projects_path, params: { name: "", min_ram_mb: "lots" }

      expect(response).to redirect_to(dashboard_path)
      expect(Project.count).to eq(0)

      follow_redirect!
      expect(inertia.props[:errors].keys).to match_array(%w[name min_ram_mb])
    end

    it "turns an empty minimum OS into none" do
      post projects_path, params: { name: "My app", min_os: "  " }

      expect(user.projects.sole.min_os).to be_nil
    end
  end

  describe "GET /projects/:id/edit" do
    it "shows the project and its keys without any secret" do
      ApiKey.generate(project, name: "prod")
      old_key, = ApiKey.generate(project, name: "old")
      old_key.update!(created_at: 1.hour.from_now)
      old_key.revoke!

      get edit_project_path(project)

      expect(response).to have_http_status(:ok)
      expect_inertia.to render_component("projects/edit")
      expect(inertia.props[:project]).to include(id: project.id, regression_ratio: 2.0, regression_min_sessions: 50)

      keys = inertia.props[:keys]
      expect(keys.pluck(:name)).to eq(%w[old prod]) # newest first
      expect(keys.first[:revoked_at]).to be_present
      expect(keys.last[:revoked_at]).to be_nil
      expect(keys.flat_map(&:keys)).not_to include("key_hash", "key", "digest")
      ApiKey.pluck(:key_hash).each { |digest| expect(response.body).not_to include(digest) }
    end
  end

  describe "PATCH /projects/:id" do
    it "updates the project and its alert thresholds" do
      patch project_path(project), params: {
        name: "Renamed", min_ram_mb: 8192, min_os: "", regression_ratio: 3, regression_min_sessions: 100
      }

      expect(response).to redirect_to(edit_project_path(project))
      expect(project.reload).to have_attributes(
        name: "Renamed", min_ram_mb: 8192, min_os: nil, regression_ratio: 3, regression_min_sessions: 100
      )

      follow_redirect!
      expect(inertia.flash[:notice]).to eq("Project updated.")
    end

    it "rejects a ratio below 1, which would flag every version" do
      patch project_path(project), params: { name: "x", regression_ratio: 0.5 }

      expect(project.reload.regression_ratio).to eq(2)

      follow_redirect!
      expect(inertia.props[:errors].keys).to eq([ "regression_ratio" ])
    end
  end

  describe "DELETE /projects/:id" do
    it "deletes the project with everything in it" do
      ApiKey.generate(project)
      session = create(:app_session, project: project)
      create(:event, :crash, project: project, app_session: session)
      create(:error_group, project: project)

      delete project_path(project)

      expect(response).to redirect_to(dashboard_path)
      expect([ Project, ApiKey, AppSession, Event, ErrorGroup ].map(&:count)).to all(eq(0))
    end
  end

  describe "someone else's project" do
    let(:other) { create(:project) }
    let(:other_key) { ApiKey.generate(other).first }

    {
      "overview" => -> { get project_path(other) },
      "errors" => -> { get project_errors_path(other) },
      "versions" => -> { get project_versions_path(other) },
      "settings" => -> { get edit_project_path(other) },
      "update" => -> { patch project_path(other), params: { name: "hacked" } },
      "delete" => -> { delete project_path(other) },
      "create key" => -> { post project_api_keys_path(other) },
      "revoke key" => -> { delete api_key_path(other_key) }
    }.each do |name, request|
      it "answers 404 for #{name} and changes nothing" do
        other_key

        instance_exec(&request)

        expect(response).to have_http_status(:not_found)
        expect(other.reload.name).not_to eq("hacked")
        expect(other.api_keys.count).to eq(1)
        expect(other_key.reload).to be_active
      end
    end
  end

  describe "when signed out" do
    before { sign_out }

    it "redirects every page to the sign in" do
      [ project_path(project), project_errors_path(project), project_versions_path(project), edit_project_path(project) ].each do |path|
        get path

        expect(response).to redirect_to(sign_in_path)
      end
    end

    it "does not create projects" do
      post projects_path, params: { name: "x" }

      expect(response).to redirect_to(sign_in_path)
      expect(Project.where(name: "x")).to be_empty
    end
  end
end
