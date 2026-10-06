require "rails_helper"

RSpec.describe ApmSimulation do
  let(:user) { create(:user) }
  let(:small) { { days: 3, users: 20 } }
  let(:key) { "apm_publicdemokey0123456789" }

  def simulate(**options)
    described_class.new(user: user, **small, **options).call
  end

  it "creates the demo project with data and a regression in the newest version" do
    result = described_class.new(user: user).call
    project = result.project

    expect(project).to have_attributes(name: "Demo App", user: user, min_ram_mb: 8192, min_os: "Windows 10")
    expect(project.events.count).to be > 1000
    expect(project.error_groups.count).to be > 0
    expect(project.app_sessions.distinct.pluck(:app_version).sort).to eq(DemoDataGenerator::VERSIONS)
    expect(project.app_sessions.where(app_version: "1.2.0").count).to be >= 50
    expect(result.events_count).to eq(project.events.count)

    rates = described_class.summary(project).to_h { |version, _sessions, _crashes, rate| [ version, rate ] }
    expect(rates["1.2.0"]).to be >= 2 * rates["1.1.0"]
  end

  it "reports progress after every batch" do
    progress = []

    described_class.new(user: user, **small).call { |stored, total| progress << [ stored, total ] }

    expect(progress.size).to be > 1
    expect(progress.last.first).to eq(progress.last.last)
  end

  it "creates an API key only the first time" do
    first = simulate
    second = simulate

    expect(first.new_api_key).to start_with("apm_")
    expect(second.new_api_key).to be_nil
    expect(ApiKey.count).to eq(1)
    expect(ApiKey.find_active(first.new_api_key).project).to eq(first.project)
  end

  it "adds to the data on the next run and replaces it with fresh" do
    first = simulate.events_count

    expect { simulate }.to change(Event, :count).by(first)
    expect { simulate(fresh: true) }.to change(Event, :count).by(-first)
  end

  it "uses the project name it is given and reuses an existing project" do
    simulate(project_name: "Other App")
    simulate(project_name: "Other App")

    expect(user.projects.pluck(:name)).to eq([ "Other App" ])
  end

  describe "with an API key" do
    it "registers that exact key, and it works on the API" do
      result = simulate(api_key: key)

      expect(result.new_api_key).to be_nil
      expect(ApiKey.find_active(key).project).to eq(result.project)
    end

    it "does not register the key twice when run again" do
      simulate(api_key: key)
      simulate(api_key: key, fresh: true)

      expect(ApiKey.count).to eq(1)
    end

    it "rejects a key in the wrong format" do
      [ "publicdemokey0123456789012", "apm_short", "apm_publicdemo-key-0123456789" ].each do |bad|
        expect { simulate(api_key: bad) }.to raise_error(described_class::Error, /apm_/)
      end

      expect(Event.count).to eq(0)
      expect(Project.count).to eq(0)
    end

    it "refuses a key that belongs to another project" do
      ApiKey.from_plain(create(:project), key)

      expect { simulate(api_key: key) }.to raise_error(described_class::Error, /another project/)
      expect(Event.count).to eq(0)
    end
  end
end
