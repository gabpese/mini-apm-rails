require "rails_helper"

RSpec.describe OsRequirement do
  describe ".below?" do
    {
      "older windows" => [ "Windows 7", "Windows 10", true ],
      "same windows" => [ "Windows 10", "Windows 10", false ],
      "newer windows" => [ "Windows 11", "Windows 10", false ],
      "compares numbers, not text" => [ "Windows 9", "Windows 10", true ],
      "older ubuntu" => [ "Ubuntu 20.04", "Ubuntu 22.04", true ],
      "newer ubuntu" => [ "Ubuntu 24.04", "Ubuntu 22.04", false ],
      "ignores case" => [ "windows 7", "Windows 10", true ]
    }.each do |name, (os, minimum, expected)|
      it "#{name}: #{os} against #{minimum}" do
        expect(described_class.below?(os, minimum)).to be(expected)
      end
    end

    it "never calls a different OS family below the minimum" do
      expect(described_class.below?("macOS 14", "Windows 10")).to be(false)
      expect(described_class.below?("Linux", "Windows 10")).to be(false)
    end

    it "ignores missing or unreadable values" do
      expect(described_class.below?(nil, "Windows 10")).to be(false)
      expect(described_class.below?("Windows 7", nil)).to be(false)
      expect(described_class.below?("Windows 7", "whatever")).to be(false)
      expect(described_class.below?("", "")).to be(false)
      expect(described_class.below?("10", "Windows 10")).to be(false)
    end
  end
end
