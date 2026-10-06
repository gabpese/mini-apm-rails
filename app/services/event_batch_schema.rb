# frozen_string_literal: true

# Validates a decoded request body against events.schema.json, the contract
# shared with the Laravel implementation.
class EventBatchSchema
  SCHEMA = JSONSchemer.schema(Rails.root.join("events.schema.json"))

  # Returns the errors as { "events.0.type" => [ "message" ] }, empty when valid.
  def self.errors_for(payload)
    SCHEMA.validate(payload).each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |error, errors|
      attribute_paths(error).each { |path| errors[path] << error.fetch("error") }
    end
  end

  # A missing property is reported on its parent object, so it is expanded to
  # one path per property: events.1.occurred_at instead of events.1.
  def self.attribute_paths(error)
    base = error.fetch("data_pointer").delete_prefix("/").tr("/", ".")
    missing = error.dig("details", "missing_keys")

    return [ base.presence || "base" ] unless missing

    missing.map { |key| [ base.presence, key ].compact.join(".") }
  end
  private_class_method :attribute_paths
end
