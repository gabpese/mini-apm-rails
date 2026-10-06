# frozen_string_literal: true

class Project < ApplicationRecord
  belongs_to :user

  has_many :api_keys, dependent: :delete_all
  has_many :events, dependent: :delete_all
  has_many :app_sessions, dependent: :delete_all
  has_many :error_groups, dependent: :delete_all

  normalizes :min_os, with: -> { _1.strip.presence }

  validates :name, presence: true, length: { maximum: 100 }
  validates :min_ram_mb, numericality: { only_integer: true, in: 0..1_048_576 }, allow_nil: true
  validates :min_os, length: { maximum: 100 }
  # A ratio below 1 would flag every version.
  validates :regression_ratio, numericality: { in: 1..99 }
  validates :regression_min_sessions, numericality: { only_integer: true, in: 1..1_000_000 }
end
