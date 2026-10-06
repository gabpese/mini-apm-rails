# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Projects", type: :system do
  let(:user) { create(:user) }

  before { sign_in user }

  def seed_regression(project)
    group = create(:error_group, project: project, occurrences: 21)

    { "1.0.0" => 1, "1.1.0" => 20 }.each do |version, crashes|
      create_list(:app_session, 100, project: project, app_version: version, started_at: 1.day.ago)
      create_list(:event, crashes, :crash, project: project, app_version: version, occurred_at: 1.day.ago, error_group: group)
    end
    create(:event, project: project, name: "export_pdf", occurred_at: 1.day.ago)
  end

  it "creates a project and shows its first API key once" do
    visit dashboard_path
    expect(page).to have_text("No projects yet")

    first(:button, "New project").click
    fill_in "Name", with: "Desktop app"
    click_on "Create project"

    expect(page).to have_text("Copy your new API key")
    expect(page).to have_text(/apm_\w{40}/)
    expect(user.projects.sole.name).to eq("Desktop app")

    visit dashboard_path
    click_on "Desktop app"
    click_on "Settings"

    expect(page).to have_no_text("Copy your new API key")
    expect(page).to have_text("Default")
  end

  it "walks through the reports of a project with a regression" do
    project = create(:project, user: user, name: "Photo editor")
    seed_regression(project)

    visit dashboard_path
    expect(page).to have_text("Photo editor")
    expect(page).to have_text("Regression")
    expect(page).to have_text("Latest version 1.1.0")

    click_on "Photo editor"
    expect(page).to have_text("Crash regression in version 1.1.0")
    expect(page).to have_text("Sessions per day")
    expect(page).to have_text("export_pdf")

    click_on "Versions"
    expect(page).to have_text("Crash rate by version")
    expect(page).to have_text("20.0× 1.0.0") # 1% of the sessions crashed in 1.0.0 and 20% in 1.1.0

    click_on "30 days" # still on the versions page, only the period is picked again
    click_on "7 days"
    expect(page).to have_current_path(project_versions_path(project, days: 7))

    click_on "Errors"
    expect(page).to have_text("Undefined method for nil")
    expect(page).to have_current_path(project_errors_path(project, days: 7))
  end

  it "creates and revokes an API key from the settings" do
    project = create(:project, user: user, name: "Photo editor")
    ApiKey.generate(project, name: "Default")

    visit edit_project_path(project)
    fill_in "key-name", with: "staging"
    click_on "Create key"

    expect(page).to have_text("Copy your new API key “staging” now")
    key = project.api_keys.find_by!(name: "staging")

    within("li", text: "staging") { click_on "Revoke" }
    within("[role=dialog]") { click_on "Revoke key" }

    expect(page).to have_text("API key revoked.")
    expect(page).to have_text("Revoked")
    expect(key.reload).not_to be_active
  end

  it "updates the project and deletes it" do
    project = create(:project, user: user, name: "Photo editor")

    visit edit_project_path(project)
    find_by_id("name").set("Photo studio")
    click_on "Save"

    expect(page).to have_text("Project updated.")
    expect(project.reload.name).to eq("Photo studio")

    click_on "Delete project"
    within("[role=dialog]") { click_on "Delete project" }

    expect(page).to have_text("Project deleted.")
    expect(page).to have_current_path(dashboard_path)
    expect(Project.count).to eq(0)
  end
end
