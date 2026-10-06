require "rails_helper"

RSpec.describe RegressionDetector do
  # Each version is [ version, sessions, crashes ].
  def detect(versions, min_sessions: 50, ratio: 2.0)
    project = build(:project, regression_ratio: ratio, regression_min_sessions: min_sessions)
    rows = versions.map { |version, sessions, crashes| { version: version, sessions: sessions, crashes: crashes } }

    described_class.new(project).detect(rows).index_by { |row| row[:version] }
  end

  it "flags a version whose crash rate reaches twice the previous one" do
    result = detect([ [ "1.0.0", 200, 2 ], [ "1.1.0", 200, 4 ] ]) # 1% -> 2%

    expect(result["1.1.0"][:regression]).to eq(previous_version: "1.0.0", previous_rate: 0.01, ratio: 2.0)
  end

  it "does not flag a version below the ratio" do
    result = detect([ [ "1.0.0", 200, 2 ], [ "1.1.0", 200, 3 ] ]) # 1% -> 1.5%

    expect(result["1.1.0"][:regression]).to be_nil
  end

  it "never flags the oldest version" do
    expect(detect([ [ "1.0.0", 200, 100 ] ])["1.0.0"][:regression]).to be_nil
  end

  it "does not flag a version with too few sessions" do
    expect(detect([ [ "1.0.0", 200, 2 ], [ "1.1.0", 49, 10 ] ])["1.1.0"][:regression]).to be_nil
  end

  it "does not trust a previous version with too few sessions" do
    expect(detect([ [ "1.0.0", 20, 0 ], [ "1.1.0", 200, 20 ] ])["1.1.0"][:regression]).to be_nil
  end

  it "compares each version with the one before it" do
    result = detect([ [ "1.0.0", 200, 2 ], [ "1.1.0", 200, 2 ], [ "1.2.0", 200, 10 ] ])

    expect(result["1.1.0"][:regression]).to be_nil
    expect(result["1.2.0"][:regression]).to include(previous_version: "1.1.0")
  end

  it "orders versions as versions, not as text" do
    result = detect([ [ "1.10.0", 200, 20 ], [ "1.9.0", 200, 2 ] ])

    expect(result.keys).to eq(%w[1.9.0 1.10.0])
    expect(result["1.10.0"][:regression]).to be_present
  end

  it "needs a few crashes to flag a version after a clean one" do
    expect(detect([ [ "1.0.0", 200, 0 ], [ "1.1.0", 200, 2 ] ])["1.1.0"][:regression]).to be_nil

    flagged = detect([ [ "1.0.0", 200, 0 ], [ "1.1.0", 200, 3 ] ])["1.1.0"][:regression]

    expect(flagged).to include(previous_version: "1.0.0", ratio: nil)
  end

  it "uses the thresholds of the project" do
    versions = [ [ "1.0.0", 200, 2 ], [ "1.1.0", 200, 3 ] ] # 1.5x

    expect(detect(versions, ratio: 1.5)["1.1.0"][:regression]).to be_present
    expect(detect(versions, min_sessions: 500, ratio: 1.5)["1.1.0"][:regression]).to be_nil
  end

  it "reports the crash rate of every version" do
    result = detect([ [ "1.0.0", 200, 5 ], [ "1.1.0", 0, 0 ] ])

    expect(result["1.0.0"][:crash_rate]).to eq(0.025)
    expect(result["1.1.0"][:crash_rate]).to eq(0.0)
  end
end
