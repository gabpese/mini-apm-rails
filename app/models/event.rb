# frozen_string_literal: true

class Event < ApplicationRecord
  TYPES = %w[session_start feature_used error crash].freeze

  belongs_to :project
  belongs_to :app_session, optional: true
  belongs_to :error_group, optional: true

  enum :event_type, TYPES.index_by(&:itself), validate: true

  validates :app_version, presence: true, length: { maximum: 32 }
  validates :occurred_at, presence: true
  validates :name, presence: true, if: :feature_used?
  validate :payload_has_message, if: -> { error? || crash? }

  # Errors and crashes are the events that belong to an error group.
  def failure?
    error? || crash?
  end

  private

  def payload_has_message
    errors.add(:payload, "must include a message") if payload.blank? || payload["message"].blank?
  end
end
