# frozen_string_literal: true

# A project's credential for the ingestion API. Only the SHA-256 digest and a
# short prefix are stored, so the plain text key exists only when it is created.
# Keys are revoked, never deleted.
class ApiKey < ApplicationRecord
  PREFIX = "apm_"
  PREFIX_LENGTH = 12

  belongs_to :project

  validates :key_prefix, presence: true
  validates :key_hash, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil) }

  class << self
    # Creates a key for the project and returns it with its plain text, which
    # cannot be recovered later.
    def generate(project, name: nil)
      plain = "#{PREFIX}#{SecureRandom.alphanumeric(40)}"

      [ from_plain(project, plain, name: name), plain ]
    end

    # Registers a key whose text is already known, such as the fixed public key of a demo.
    def from_plain(project, plain, name: nil)
      project.api_keys.create!(name: name, key_prefix: plain.first(PREFIX_LENGTH), key_hash: digest(plain))
    end

    def digest(plain)
      Digest::SHA256.hexdigest(plain)
    end

    def find_active(plain)
      active.find_by(key_hash: digest(plain))
    end
  end

  def active?
    revoked_at.nil?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  # Skips the write when the key was already used in the last minute.
  def touch_last_used!
    return if last_used_at && last_used_at > 1.minute.ago

    update_columns(last_used_at: Time.current)
  end
end
