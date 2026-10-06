require "rails_helper"

RSpec.describe ErrorGroup do
  describe ".fingerprint_for" do
    it "is the same for the same message and first stack line" do
      a = described_class.fingerprint_for("Boom", "app.rb:10\nother.rb:1")
      b = described_class.fingerprint_for("Boom", "app.rb:10\nelsewhere.rb:99")

      expect(a).to eq(b)
      expect(a).to match(/\A\h{64}\z/)
    end

    it "changes with the message or the first stack line" do
      base = described_class.fingerprint_for("Boom", "app.rb:10")

      expect(described_class.fingerprint_for("Other", "app.rb:10")).not_to eq(base)
      expect(described_class.fingerprint_for("Boom", "app.rb:11")).not_to eq(base)
    end

    it "accepts a missing stack" do
      expect(described_class.fingerprint_for("Boom")).to eq(described_class.fingerprint_for("Boom", ""))
    end
  end

  describe "#record_occurrence!" do
    it "counts the occurrence and widens the seen window" do
      group = create(:error_group, first_seen_at: Time.utc(2026, 10, 20, 12), last_seen_at: Time.utc(2026, 10, 20, 12), occurrences: 1)

      group.record_occurrence!(Time.utc(2026, 10, 21, 9))
      group.record_occurrence!(Time.utc(2026, 10, 19, 8))
      group.reload

      expect(group.occurrences).to eq(3)
      expect(group.first_seen_at).to eq(Time.utc(2026, 10, 19, 8))
      expect(group.last_seen_at).to eq(Time.utc(2026, 10, 21, 9))
    end
  end

  it "allows one group per fingerprint in each project" do
    group = create(:error_group)

    expect(build(:error_group, project: group.project, fingerprint: group.fingerprint)).not_to be_valid
    expect(build(:error_group, fingerprint: group.fingerprint)).to be_valid
  end
end
