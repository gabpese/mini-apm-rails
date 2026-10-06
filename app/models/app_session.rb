# frozen_string_literal: true

# One run of the monitored app, opened by a session_start event. Named
# AppSession because Session is already the login session of the starter kit.
class AppSession < ApplicationRecord
  belongs_to :project

  has_many :events, dependent: :nullify

  validates :app_version, presence: true, length: { maximum: 32 }
  validates :started_at, presence: true
  validates :ram_mb, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # The latest session of the user on this version that had started by the given time.
  def self.latest_for(user_ref:, app_version:, at:)
    where(user_ref: user_ref, app_version: app_version, started_at: ..at).order(started_at: :desc).first
  end
end
