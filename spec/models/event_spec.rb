require "rails_helper"

RSpec.describe Event do
  it "has a valid factory for every type" do
    expect(build(:event)).to be_valid
    expect(build(:event, :session_start)).to be_valid
    expect(build(:event, :crash)).to be_valid
    expect(build(:event, :error)).to be_valid
  end

  it "rejects an unknown type" do
    expect(build(:event, event_type: "bogus")).not_to be_valid
  end

  it "requires a name for feature_used events" do
    expect(build(:event, name: nil)).not_to be_valid
  end

  it "requires a message for errors and crashes" do
    expect(build(:event, :crash, payload: nil)).not_to be_valid
    expect(build(:event, :error, payload: { "stack" => "app.rb:1" })).not_to be_valid
  end

  it "knows which events are failures" do
    expect(build(:event, :crash)).to be_failure
    expect(build(:event, :error)).to be_failure
    expect(build(:event)).not_to be_failure
  end

  it "keeps the event when its session or error group is deleted" do
    session = create(:app_session)
    group = create(:error_group, project: session.project)
    event = create(:event, :crash, project: session.project, app_session: session, error_group: group)

    session.destroy!
    group.destroy!

    expect(event.reload).to have_attributes(app_session_id: nil, error_group_id: nil)
  end
end
