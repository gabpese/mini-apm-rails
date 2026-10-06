require "rails_helper"

RSpec.describe ApiKey do
  let(:project) { create(:project) }

  describe ".generate" do
    it "returns the key and its plain text, storing only the digest and a prefix" do
      api_key, plain = described_class.generate(project, name: "Production")

      expect(plain).to start_with("apm_")
      expect(api_key).to have_attributes(
        project: project,
        name: "Production",
        key_prefix: plain.first(12),
        key_hash: Digest::SHA256.hexdigest(plain)
      )
      expect(api_key.attributes.values).not_to include(plain)
    end

    it "generates a different key every time" do
      _, first = described_class.generate(project)
      _, second = described_class.generate(project)

      expect(first).not_to eq(second)
    end
  end

  describe ".find_active" do
    it "finds the key by its plain text" do
      api_key, plain = described_class.generate(project)

      expect(described_class.find_active(plain)).to eq(api_key)
    end

    it "does not find an unknown or revoked key" do
      api_key, plain = described_class.generate(project)
      api_key.revoke!

      expect(described_class.find_active(plain)).to be_nil
      expect(described_class.find_active("apm_unknown")).to be_nil
    end
  end

  describe "#revoke!" do
    it "fills revoked_at and keeps the record" do
      api_key, = described_class.generate(project)

      expect { api_key.revoke! }.to change(api_key, :active?).from(true).to(false)
      expect(api_key.revoked_at).to be_present
      expect(described_class.exists?(api_key.id)).to be(true)
    end
  end

  describe "#touch_last_used!" do
    it "records the first use and skips the write within a minute" do
      api_key, = described_class.generate(project)

      api_key.touch_last_used!
      first_use = api_key.reload.last_used_at
      expect(first_use).to be_present

      travel_to(30.seconds.from_now) { api_key.touch_last_used! }
      expect(api_key.reload.last_used_at).to eq(first_use)

      travel_to(2.minutes.from_now) { api_key.touch_last_used! }
      expect(api_key.reload.last_used_at).to be > first_use
    end
  end

  it "requires a unique digest" do
    existing = create(:api_key)

    expect(build(:api_key, key_hash: existing.key_hash)).not_to be_valid
  end
end
