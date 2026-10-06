# frozen_string_literal: true

# The numbers shown on a project's dashboard for the last +days+ days. Everything
# is computed with aggregate queries, so the cost does not grow with the number
# of events. The versions are the exception: they cover the life of the project.
class ProjectStats
  PERIODS = [ 7, 30, 90 ].freeze
  DEFAULT_PERIOD = 30

  # The day a row falls on, to group the charts by.
  DAY_OF = { started_at: Arel.sql("DATE(started_at)"), occurred_at: Arel.sql("DATE(occurred_at)") }.freeze

  # Anything past this many distinct groups is folded into "Other".
  DISTRIBUTION_LIMITS = { os: 6, ram: 6, gpu: 8 }.freeze

  def initialize(project, days: DEFAULT_PERIOD)
    @project = project
    @days = days
  end

  # Start of the first day of the period, which ends today.
  def since
    @since ||= Time.current.beginning_of_day - (days - 1).days
  end

  def totals
    sessions = project.app_sessions.where(started_at: since..)
    sessions_count = sessions.count
    crashes = period_events.crash.count

    {
      sessions: sessions_count,
      users: sessions.distinct.count(:user_ref),
      errors: period_events.error.count,
      crashes: crashes,
      crash_rate: sessions_count.positive? ? crashes.fdiv(sessions_count) : 0.0
    }
  end

  # The small summary shown on the project list.
  def summary
    totals.slice(:sessions, :crashes, :crash_rate).merge(
      latest_version: versions.last&.fetch(:version),
      regression: latest_regression.present?
    )
  end

  # One row per day of the period, including days with no data.
  def daily
    sessions = project.app_sessions.where(started_at: since..).group(day_of(:started_at)).count
    failures = period_events.where(event_type: %w[error crash]).group(day_of(:occurred_at), :event_type).count

    each_day.map do |day|
      {
        date: day.iso8601,
        sessions: sessions.fetch(day, 0),
        errors: failures.fetch([ day, "error" ], 0),
        crashes: failures.fetch([ day, "crash" ], 0)
      }
    end
  end

  def top_features(limit = 8)
    period_events.feature_used
      .group(:name)
      .order(Arel.sql("COUNT(*) DESC"), :name)
      .limit(limit)
      .count
      .map { |name, uses| { name: name, uses: uses } }
  end

  # Error groups with at least one occurrence in the period, most frequent first.
  def error_groups(limit = 50)
    project.error_groups
      .joins(:events)
      .where(events: { occurred_at: since.. })
      .group("error_groups.id")
      .order(Arel.sql("COUNT(events.id) DESC"), :id)
      .limit(limit)
      .pluck(
        "error_groups.id", "error_groups.message", Arel.sql("COUNT(events.id)"),
        Arel.sql("COUNT(events.id) FILTER (WHERE events.event_type = 'crash')"),
        "error_groups.first_seen_at", "error_groups.last_seen_at"
      )
      .map do |id, message, occurrences, crashes, first_seen_at, last_seen_at|
        { id: id, message: message, occurrences: occurrences, crashes: crashes,
          first_seen_at: first_seen_at.iso8601, last_seen_at: last_seen_at.iso8601 }
      end
  end

  # Sessions, users and crash rate per version over the whole life of the
  # project, oldest first, with the regression alert already applied.
  def versions
    @versions ||= begin
      crashes = project.events.crash.group(:app_version).count

      rows = project.app_sessions.group(:app_version)
        .pluck(:app_version, Arel.sql("COUNT(*)"), Arel.sql("COUNT(DISTINCT user_ref)"))
        .map { |version, sessions, users| { version: version, sessions: sessions, users: users, crashes: crashes.fetch(version, 0) } }

      RegressionDetector.new(project).detect(rows)
    end
  end

  # The regression of the newest version, if it has one. Older flagged versions
  # are history: the alert is about what users run today.
  def latest_regression
    latest = versions.last

    return unless latest&.fetch(:regression)

    { version: latest[:version], crash_rate: latest[:crash_rate] }.merge(latest[:regression])
  end

  # Sessions per day and version, to show how fast each release is adopted.
  def adoption
    counts = project.app_sessions.where(started_at: since..).group(day_of(:started_at), :app_version).count
    names = counts.keys.map(&:last).uniq.sort_by { |version| AppVersion.new(version) }

    rows = each_day.map do |day|
      { "date" => day.iso8601 }.merge(names.index_with { |version| counts.fetch([ day, version ], 0) })
    end

    { versions: names, rows: rows }
  end

  # What the machines running the app look like, and who is under the
  # project's minimum requirements.
  def environment
    machines = project.app_sessions.where(started_at: since..)
      .group(:os, :ram_mb, :gpu)
      .pluck(:os, :ram_mb, :gpu, Arel.sql("COUNT(DISTINCT user_ref)"))

    below_ram = below_os = below_minimum = 0
    os = Hash.new(0)
    ram = Hash.new(0)
    gpu = Hash.new(0)

    machines.each do |machine_os, ram_mb, machine_gpu, users|
      low_ram = project.min_ram_mb && ram_mb && ram_mb < project.min_ram_mb
      old_os = OsRequirement.below?(machine_os, project.min_os)

      below_ram += users if low_ram
      below_os += users if old_os
      below_minimum += users if low_ram || old_os

      os[machine_os || "Unknown"] += users
      ram[ram_mb ? ram_label(ram_mb) : "Unknown"] += users
      gpu[machine_gpu || "Unknown"] += users
    end

    {
      users: machines.sum { |*, users| users },
      below_minimum: below_minimum,
      below_ram: below_ram,
      below_os: below_os,
      os: distribution(os, DISTRIBUTION_LIMITS[:os]),
      ram: distribution(ram, DISTRIBUTION_LIMITS[:ram]),
      gpu: distribution(gpu, DISTRIBUTION_LIMITS[:gpu])
    }
  end

  private

  attr_reader :project, :days

  def period_events
    project.events.where(occurred_at: since..)
  end

  def each_day
    since.to_date..Date.current
  end

  def day_of(column)
    DAY_OF.fetch(column)
  end

  # The biggest groups, most users first, with the long tail folded into "Other".
  def distribution(counts, limit)
    rows = counts.sort_by { |label, users| [ -users, label ] }.map { |label, users| { label: label, users: users } }
    top = rows.first(limit)
    other = rows.drop(limit).sum { |row| row[:users] }

    other.positive? ? top + [ { label: "Other", users: other } ] : top
  end

  def ram_label(megabytes)
    megabytes >= 1024 ? "#{(megabytes / 1024.0).round} GB" : "#{megabytes} MB"
  end
end
