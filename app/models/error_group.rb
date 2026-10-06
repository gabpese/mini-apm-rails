# frozen_string_literal: true

# Errors and crashes that share a message and a first stack line.
class ErrorGroup < ApplicationRecord
  belongs_to :project

  has_many :events, dependent: :nullify

  validates :fingerprint, presence: true, uniqueness: { scope: :project_id }
  validates :message, presence: true
  validates :first_seen_at, :last_seen_at, presence: true

  # The same message and first stack line always give the same fingerprint.
  def self.fingerprint_for(message, stack = nil)
    location = stack.to_s.split("\n").find { |line| !line.empty? }

    Digest::SHA256.hexdigest("#{message}\n#{location}")
  end

  # Finds or opens the group of an error and counts the occurrence. The insert
  # leaves the conflict to the unique index, so two batches opening the same
  # group at once end up sharing it.
  def self.record!(project, message:, stack:, occurred_at:)
    fingerprint = fingerprint_for(message, stack)

    insert(
      { project_id: project.id, fingerprint: fingerprint, message: message, first_seen_at: occurred_at, last_seen_at: occurred_at, occurrences: 0 },
      unique_by: %i[project_id fingerprint]
    )

    project.error_groups.find_by!(fingerprint: fingerprint).tap { |group| group.record_occurrence!(occurred_at) }
  end

  # Counts one more occurrence, widening the first/last seen window. Runs as a
  # single UPDATE so concurrent batches do not lose counts.
  def record_occurrence!(occurred_at)
    self.class.where(id: id).update_all([
      "occurrences = occurrences + 1, first_seen_at = LEAST(first_seen_at, :at), last_seen_at = GREATEST(last_seen_at, :at)",
      { at: occurred_at }
    ])
  end
end
