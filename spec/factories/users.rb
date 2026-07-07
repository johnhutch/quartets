FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "admin#{n}@example.com" }
    password { "correct-horse-battery-staple" }

    trait :superuser do
      superuser { true }
    end
  end
end
