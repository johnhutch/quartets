FactoryBot.define do
  factory :report do
    association :puzzle, factory: :published_puzzle
    sequence(:reporter_token) { |n| "reporter-#{n}" }
    reason { "This category is unfair." }

    trait :resolved do
      resolution { :wontdo }
      resolved_at { Time.current }
    end
  end

  factory :report_comment do
    report
    association :user, factory: %i[user moderator]
    body { "Taking a look." }
  end
end
