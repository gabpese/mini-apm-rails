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

  # Counts one more occurrence, widening the first/last seen window. Runs as a
  # single UPDATE so concurrent batches do not lose counts.
  def record_occurrence!(occurred_at)
    self.class.where(id: id).update_all([
      "occurrences = occurrences + 1, first_seen_at = LEAST(first_seen_at, :at), last_seen_at = GREATEST(last_seen_at, :at)",
      { at: occurred_at }
    ])
  end
end
