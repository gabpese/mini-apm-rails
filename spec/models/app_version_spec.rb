require "rails_helper"

RSpec.describe AppVersion do
  def sorted(*versions)
    versions.sort_by { |version| described_class.new(version) }
  end

  it "orders versions as versions, not as text" do
    expect(sorted("1.10.0", "1.9.0", "1.2.0")).to eq(%w[1.2.0 1.9.0 1.10.0])
  end

  it "puts a shorter version before the longer one it starts" do
    expect(sorted("1.0.1", "1.0")).to eq(%w[1.0 1.0.1])
  end

  it "accepts versions that are not numeric" do
    expect(sorted("2.0.0", "beta", "1.0.0-rc")).to eq(%w[beta 1.0.0-rc 2.0.0])
  end

  it "compares equal versions as equal" do
    expect(described_class.new("1.2.0")).to eq(described_class.new("1.2.0"))
  end
end
