# frozen_string_literal: true

class Project < ApplicationRecord
  belongs_to :user

  has_many :api_keys, dependent: :delete_all
  has_many :events, dependent: :delete_all
  has_many :app_sessions, dependent: :delete_all
  has_many :error_groups, dependent: :delete_all

  validates :name, presence: true, length: { maximum: 255 }
  validates :min_ram_mb, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :min_os, length: { maximum: 255 }
  validates :regression_ratio, numericality: { greater_than: 0 }
  validates :regression_min_sessions, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
