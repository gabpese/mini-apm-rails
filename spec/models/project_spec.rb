require "rails_helper"

RSpec.describe Project do
  it "has the regression defaults" do
    project = create(:project)

    expect(project).to have_attributes(regression_ratio: 2, regression_min_sessions: 50, min_ram_mb: nil, min_os: nil)
  end

  it "requires a name and an owner" do
    expect(build(:project, name: "")).not_to be_valid
    expect(build(:project, user: nil)).not_to be_valid
  end

  it "validates the regression settings" do
    expect(build(:project, regression_ratio: 0)).not_to be_valid
    expect(build(:project, regression_min_sessions: -1)).not_to be_valid
    expect(build(:project, min_ram_mb: -1)).not_to be_valid
  end

  it "removes its data when destroyed" do
    project = create(:project)
    ApiKey.generate(project)
    session = create(:app_session, project: project)
    create(:event, :crash, project: project, app_session: session)
    create(:error_group, project: project)

    expect { project.destroy! }
      .to change(ApiKey, :count).by(-1)
      .and change(Event, :count).by(-1)
      .and change(AppSession, :count).by(-1)
      .and change(ErrorGroup, :count).by(-1)
  end
end
