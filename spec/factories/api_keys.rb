FactoryBot.define do
  factory :api_key do
    project
    sequence(:name) { |n| "Key #{n}" }
    key_prefix { "apm_test" }
    sequence(:key_hash) { |n| ApiKey.digest("apm_factory_key_#{n}") }
  end
end
