# frozen_string_literal: true

# Flags a version whose crash rate is much higher than the version before it.
#
# Crash rate = crashes / sessions of the version. A version is flagged when its
# rate reaches the project's regression_ratio times the previous one, and only
# when both versions have at least regression_min_sessions sessions, so a
# handful of sessions cannot raise a false alarm.
#
# When the previous version had no crashes at all the ratio is infinite, so the
# version is flagged only if it has at least MIN_CRASHES_WHEN_PREVIOUS_IS_ZERO.
class RegressionDetector
  MIN_CRASHES_WHEN_PREVIOUS_IS_ZERO = 3

  def initialize(project)
    @project = project
  end

  # Takes [ { version:, sessions:, crashes: } ] in any order and returns the
  # versions oldest first, each with its crash_rate and, when flagged, its
  # regression: { previous_version:, previous_rate:, ratio: }.
  def detect(versions)
    previous = nil

    versions.sort_by { |row| AppVersion.new(row[:version]) }.map do |row|
      current = row.merge(crash_rate: crash_rate(row))

      current.merge(regression: previous && regression(previous, current)).tap { previous = current }
    end
  end

  private

  attr_reader :project

  def crash_rate(row)
    row[:sessions].positive? ? row[:crashes].fdiv(row[:sessions]) : 0.0
  end

  def regression(previous, current)
    return unless enough_sessions?(previous, current) && current[:crashes].positive?
    return unless flagged?(previous, current)

    {
      previous_version: previous[:version],
      previous_rate: previous[:crash_rate],
      ratio: previous[:crash_rate].positive? ? current[:crash_rate] / previous[:crash_rate] : nil
    }
  end

  def enough_sessions?(previous, current)
    [ previous, current ].all? { |row| row[:sessions] >= project.regression_min_sessions }
  end

  def flagged?(previous, current)
    if previous[:crash_rate].zero?
      current[:crashes] >= MIN_CRASHES_WHEN_PREVIOUS_IS_ZERO
    else
      current[:crash_rate] >= project.regression_ratio.to_f * previous[:crash_rate]
    end
  end
end
