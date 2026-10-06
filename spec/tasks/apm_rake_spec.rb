require "rails_helper"
require "rake"

RSpec.describe "apm:simulate" do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("apm:simulate") }

  let(:task) { Rake::Task["apm:simulate"] }

  around do |example|
    original = ENV.to_h
    ENV.update("DAYS" => "3", "USERS" => "20")
    example.run
  ensure
    ENV.replace(original)
  end

  before do
    task.reenable
    User.destroy_all # the starter kit fixtures already load two users
  end

  it "fills the demo project of the first user and prints the summary and the new key once" do
    user = create(:user)

    expect { task.invoke }.to output(/Sending events.*Version.*1\.2\.0.*API key created.*apm_\w+/m).to_stdout

    expect(user.projects.sole.events.count).to be > 0

    task.reenable
    expect { task.invoke }.not_to output(/API key created/).to_stdout
  end

  it "aborts when there is no user" do
    expect { task.invoke }.to raise_error(SystemExit).and output(/No user found/).to_stderr
  end

  it "aborts on an API key in the wrong format" do
    create(:user)
    ENV["API_KEY"] = "nope"

    expect { task.invoke }.to raise_error(SystemExit).and output(/The API key must be apm_/).to_stderr
  end

  it "takes the owner from USER_EMAIL" do
    create(:user)
    second = create(:user)
    ENV["USER_EMAIL"] = second.email

    expect { task.invoke }.to output.to_stdout

    expect(Project.sole.user).to eq(second)
  end
end
