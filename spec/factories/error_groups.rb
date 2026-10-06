FactoryBot.define do
  factory :error_group do
    project
    message { "Undefined method for nil" }
    fingerprint { ErrorGroup.fingerprint_for(message, "app.rb:10:in `run`") }
    first_seen_at { Time.zone.parse("2026-10-20T14:07:40Z") }
    last_seen_at { first_seen_at }
    occurrences { 1 }
  end
end
