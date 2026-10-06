# frozen_string_literal: true

# Stores a validated batch of events for a project.
#
# A session_start event opens an AppSession. Any other event is linked to the
# latest session of the same user and app version, and errors and crashes are
# grouped by fingerprint.
class EventIngestor
  def initialize(project)
    @project = project
  end

  # Returns how many events were stored. The batch is stored all or nothing.
  def ingest(events)
    # Process in the order events happened, so a session exists before its events.
    ordered = events.sort_by.with_index { |event, index| [ occurred_at(event), index ] }

    Event.transaction do
      ordered.each { |event| store(event) }
    end

    ordered.size
  end

  private

  attr_reader :project

  def store(data)
    time = occurred_at(data)
    type = data.fetch("type")

    session = type == "session_start" ? open_session(data, time) : find_session(data, time)
    group = record_error(data, time) if %w[error crash].include?(type)

    project.events.create!(
      app_session: session,
      error_group: group,
      event_type: type,
      name: data["name"],
      app_version: data["app_version"],
      user_ref: data["user_ref"],
      occurred_at: time,
      payload: data.slice("message", "stack", "properties").compact.presence
    )
  end

  def open_session(data, time)
    env = data["env"] || {}

    project.app_sessions.create!(
      user_ref: data["user_ref"],
      app_version: data["app_version"],
      os: env["os"],
      ram_mb: env["ram_mb"],
      gpu: env["gpu"],
      started_at: time
    )
  end

  def find_session(data, time)
    return if data["user_ref"].blank?

    project.app_sessions.latest_for(user_ref: data["user_ref"], app_version: data["app_version"], at: time)
  end

  def record_error(data, time)
    ErrorGroup.record!(project, message: data["message"], stack: data["stack"], occurred_at: time)
  end

  def occurred_at(data)
    Time.iso8601(data.fetch("occurred_at"))
  end
end
