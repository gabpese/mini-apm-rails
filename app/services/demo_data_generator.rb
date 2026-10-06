# frozen_string_literal: true

# Builds weeks of realistic, fictional usage for an invented desktop app.
#
# The newest version has a deliberate crash regression, so the dashboard always
# has something to show. The same seed always gives the same history.
class DemoDataGenerator
  VERSIONS = %w[1.0.0 1.1.0 1.2.0].freeze

  # Share of sessions that end in a crash, per version.
  CRASH_RATES = { "1.0.0" => 0.015, "1.1.0" => 0.018, "1.2.0" => 0.07 }.freeze

  FEATURES = {
    "export_pdf" => 30,
    "import_csv" => 22,
    "share" => 15,
    "dark_mode" => 10,
    "advanced_search" => 14,
    "sync" => 9
  }.freeze

  ERRORS = [
    [ "Timeout while syncing with the server", "sync.rb:41:in `push`" ],
    [ "Invalid CSV file format", "importer.rb:18:in `parse`" ],
    [ "Failed to generate the PDF", "exporter.rb:77:in `render`" ]
  ].freeze

  COMMON_CRASHES = [
    [ "Undefined method for nil", "cache.rb:12:in `fetch`" ],
    [ "Out of memory", "loader.rb:9:in `load_all`" ]
  ].freeze

  REGRESSION_CRASH = [ "NoMethodError: undefined method `render_chart` for nil", "dashboard.rb:56:in `draw`" ].freeze

  MACHINES = [
    [ "Windows 11", 16_384, "RTX 3060" ],
    [ "Windows 11", 8192, "GTX 1660" ],
    [ "Windows 10", 8192, "Intel UHD" ],
    [ "Windows 10", 4096, "Intel UHD" ],
    [ "Windows 10", 2048, "Intel HD" ],
    [ "Windows 7", 4096, "Intel HD" ],
    [ "macOS 14", 16_384, "Apple M2" ],
    [ "Ubuntu 24.04", 8192, "Intel UHD" ]
  ].freeze

  DemoUser = Struct.new(:ref, :machine, :delay)

  def initialize(days: 30, users: 150, seed: 42, until_time: Time.current)
    @days = days
    @users = users
    @seed = seed
    @end_time = until_time.utc
  end

  # Returns the events in the API batch format, oldest first.
  def generate
    @random = Random.new(@seed)
    start = @end_time.beginning_of_day - (@days - 1).days
    pool = Array.new(@users) { |index| build_user(index) }

    events = @days.times.flat_map do |day|
      date = start + day.days

      pool.flat_map do |user|
        next [] if @random.rand(1..100) > 35

        session(user, version_for(day, user.delay), date)
      end
    end

    events.sort_by.with_index { |event, index| [ event["occurred_at"], index ] }
  end

  private

  # Each user has a fixed machine and updates some days after a release.
  def build_user(index)
    DemoUser.new(
      "u_#{Digest::SHA256.hexdigest("#{@seed}-#{index}").first(6)}",
      MACHINES.fetch(@random.rand(MACHINES.size)),
      @random.rand(0..5)
    )
  end

  # 1.0.0 is out from day one, 1.1.0 two weeks and 1.2.0 one week before the end,
  # so the regression is recent but already has enough sessions to show.
  # Each user adopts a release a few days after it ships.
  def version_for(day, delay)
    releases = { "1.0.0" => 0, "1.1.0" => [ 1, @days - 14 ].max, "1.2.0" => [ 2, @days - 7 ].max }

    releases.select { |_, release_day| day >= release_day + delay }.keys.last || "1.0.0"
  end

  def session(user, version, date)
    at = session_start_time(date)
    base = { "app_version" => version, "user_ref" => user.ref }
    os, ram_mb, gpu = user.machine

    events = [ base.merge("type" => "session_start", "occurred_at" => iso(at), "env" => { "os" => os, "ram_mb" => ram_mb, "gpu" => gpu }) ]

    @random.rand(2..6).times do
      at += @random.rand(20..600)
      events << base.merge("type" => "feature_used", "name" => weighted(FEATURES), "occurred_at" => iso(at))
    end

    if @random.rand(1..100) <= 8
      message, stack = ERRORS.fetch(@random.rand(ERRORS.size))
      events << base.merge("type" => "error", "message" => message, "stack" => stack, "occurred_at" => iso(at + @random.rand(5..60)))
    end

    if @random.rand(1..10_000) <= CRASH_RATES.fetch(version) * 10_000
      message, stack = crash_for(version)
      events << base.merge("type" => "crash", "message" => message, "stack" => stack, "occurred_at" => iso(at + @random.rand(60..300)))
    end

    # Today is only partly over: drop what would happen after "now". Done after the
    # random draws, so the same seed keeps producing the same history up to this moment.
    events.select { |event| Time.iso8601(event["occurred_at"]) <= @end_time }
  end

  # A full day has its sessions between 8:00 and 22:00. Today is still going on, so
  # its sessions are spread from midnight to "now" (leaving room for the events that
  # follow a session start). Otherwise the last point of every chart would fall to
  # zero, as if the app had gone down.
  def session_start_time(date)
    elapsed = (@end_time - date).to_i

    if elapsed < 1.day
      date + @random.rand(0..[ elapsed - 1.hour.to_i, 0 ].max)
    else
      date + @random.rand((8 * 3600)..(22 * 3600))
    end
  end

  def crash_for(version)
    if version == "1.2.0" && @random.rand(1..100) <= 80
      REGRESSION_CRASH
    else
      COMMON_CRASHES.fetch(@random.rand(COMMON_CRASHES.size))
    end
  end

  def weighted(weights)
    pick = @random.rand(1..weights.values.sum)

    weights.each do |name, weight|
      pick -= weight
      return name if pick <= 0
    end
  end

  def iso(time)
    time.utc.iso8601
  end
end
