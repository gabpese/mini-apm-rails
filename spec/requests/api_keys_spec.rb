require "rails_helper"

RSpec.describe "API keys", type: :request do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }

  before { sign_in user }

  describe "POST /projects/:project_id/api_keys" do
    it "creates a named key and shows it once" do
      post project_api_keys_path(project), params: { name: "staging" }

      expect(response).to redirect_to(edit_project_path(project))
      expect(project.api_keys.sole.name).to eq("staging")

      follow_redirect!
      expect(inertia.flash[:new_key]).to include(name: "staging", key: /\Aapm_/)
      expect(ApiKey.find_active(inertia.flash[:new_key][:key])).to eq(project.api_keys.sole)
    end

    it "creates an unnamed key" do
      post project_api_keys_path(project)

      expect(project.api_keys.sole.name).to be_nil
    end

    it "rejects a name that is too long" do
      post project_api_keys_path(project), params: { name: "x" * 101 }

      expect(project.api_keys.count).to eq(0)

      follow_redirect!
      expect(inertia.props[:errors].keys).to eq([ "name" ])
    end
  end

  describe "DELETE /api_keys/:id" do
    it "revokes the key, which then stops working on the API" do
      key, plain = ApiKey.generate(project)

      delete api_key_path(key)

      expect(response).to redirect_to(edit_project_path(project))
      expect(key.reload).not_to be_active

      post "/api/v1/events", params: { events: [] }.to_json, headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{plain}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "keeps the key listed as revoked and does not change when revoked again" do
      key, = ApiKey.generate(project)
      key.revoke!
      revoked_at = key.revoked_at

      delete api_key_path(key)

      expect(key.reload.revoked_at).to eq(revoked_at)
      expect(project.api_keys.count).to eq(1)
    end
  end
end
