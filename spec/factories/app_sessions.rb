FactoryBot.define do
  factory :app_session do
    project
    user_ref { "u_8f3a" }
    app_version { "1.2.0" }
    os { "Windows 11" }
    ram_mb { 16_384 }
    gpu { "GTX 1660" }
    started_at { Time.zone.parse("2026-10-20T14:03:00Z") }
  end
end
