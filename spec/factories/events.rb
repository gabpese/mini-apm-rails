FactoryBot.define do
  factory :event do
    project
    event_type { "feature_used" }
    name { "export_pdf" }
    app_version { "1.2.0" }
    user_ref { "u_8f3a" }
    occurred_at { Time.zone.parse("2026-10-20T14:05:12Z") }

    trait :session_start do
      event_type { "session_start" }
      name { nil }
    end

    trait :crash do
      event_type { "crash" }
      name { nil }
      payload { { "message" => "Undefined method for nil", "stack" => "app.rb:10:in `run`\napp.rb:3" } }
    end

    trait :error do
      crash
      event_type { "error" }
    end
  end
end
