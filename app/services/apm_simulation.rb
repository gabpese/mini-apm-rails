# frozen_string_literal: true

# Fills a demo project with fictional usage, running the events through the same
# EventIngestor as the API. Behind the apm:simulate rake task.
class ApmSimulation
  class Error < StandardError; end

  DEFAULT_PROJECT_NAME = "Demo App"
  API_KEY_FORMAT = /\Aapm_[A-Za-z0-9]{20,}\z/
  BATCH_SIZE = 100

  Result = Struct.new(:project, :events_count, :new_api_key)

  # +api_key+ registers that exact key (apm_ and 20+ letters or digits), for a
  # public demo with a known key.
  def initialize(user:, project_name: DEFAULT_PROJECT_NAME, days: 30, users: 150, seed: 42, api_key: nil, fresh: false)
    @user = user
    @project_name = project_name
    @days = days
    @users = users
    @seed = seed
    @api_key = api_key
    @fresh = fresh
  end

  # Yields how many events were stored so far and the total, after each batch.
  def call
    raise Error, "The API key must be apm_ followed by at least 20 letters or digits." if @api_key && !@api_key.match?(API_KEY_FORMAT)

    project = find_or_create_project
    register_fixed_key(project) if @api_key
    clear(project) if @fresh

    events = DemoDataGenerator.new(days: @days, users: @users, seed: @seed).generate
    ingestor = EventIngestor.new(project)
    stored = 0

    events.each_slice(BATCH_SIZE) do |batch|
      stored += ingestor.ingest(batch)
      yield stored, events.size if block_given?
    end

    Result.new(project, events.size, generate_key_if_missing(project))
  end

  # One row per version: [ version, sessions, crashes, crash rate ].
  def self.summary(project)
    DemoDataGenerator::VERSIONS.map do |version|
      sessions = project.app_sessions.where(app_version: version).count
      crashes = project.events.crash.where(app_version: version).count

      [ version, sessions, crashes, sessions.zero? ? nil : (crashes * 100.0 / sessions).round(1) ]
    end
  end

  private

  def find_or_create_project
    @user.projects.find_or_create_by!(name: @project_name) do |project|
      project.min_ram_mb = 8192
      project.min_os = "Windows 10"
    end
  end

  def register_fixed_key(project)
    existing = ApiKey.find_by(key_hash: ApiKey.digest(@api_key))

    raise Error, "That API key already belongs to another project." if existing && existing.project_id != project.id

    ApiKey.from_plain(project, @api_key, name: "demo") unless existing
  end

  def clear(project)
    project.events.delete_all
    project.app_sessions.delete_all
    project.error_groups.delete_all
  end

  # The plain text key only exists when it is created, so a key is made the first
  # time and never shown again. A key given with --api-key was already registered.
  def generate_key_if_missing(project)
    return if project.api_keys.exists?

    ApiKey.generate(project, name: "demo").last
  end
end
