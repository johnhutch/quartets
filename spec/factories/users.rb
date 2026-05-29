FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "admin#{n}@example.com" }
    password { "correct-horse-battery-staple" }
  end
end
