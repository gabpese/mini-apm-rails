# frozen_string_literal: true

# Orders the version strings apps send as versions, not as text: 1.9.0 comes
# before 1.10.0. Any text is accepted, since apps pick their own scheme.
class AppVersion
  include Comparable

  attr_reader :to_s

  def initialize(string)
    @to_s = string.to_s
  end

  def <=>(other)
    sort_key <=> other.sort_key
  end

  protected

  # Digit runs compare as numbers and the rest as text, so 1.10 > 1.9 and 1.0.0-rc > 1.0.0-beta.
  def sort_key
    to_s.scan(/\d+|\D+/).map { |part| part.match?(/\d/) ? [ 1, part.to_i, "" ] : [ 0, 0, part ] }
  end
end
