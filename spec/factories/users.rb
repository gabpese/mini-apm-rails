FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n}" }
    sequence(:email) { |n| "user#{n}@factory.example.com" }
    password { "Secret1*3*5*" }
    verified { true }
  end
end
