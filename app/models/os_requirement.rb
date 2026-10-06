# frozen_string_literal: true

# Compares an operating system name against a project's minimum, such as
# "Windows 7" against "Windows 10". Only the same OS family can be below the
# minimum: "macOS 14" is never "below" "Windows 10".
module OsRequirement
  NAME_AND_VERSION = /\A(?<family>.*?)\s*(?<version>\d+(?:\.\d+)*)\z/

  def self.below?(os, minimum)
    current = parse(os)
    required = parse(minimum)

    return false if current.nil? || required.nil? || current.first != required.first

    Gem::Version.new(current.last) < Gem::Version.new(required.last)
  end

  # Returns [ family in lower case, version ], or nil when the text has no version.
  def self.parse(os)
    match = NAME_AND_VERSION.match(os.to_s.strip)

    [ match[:family].downcase, match[:version] ] if match && match[:family].present?
  end
  private_class_method :parse
end
