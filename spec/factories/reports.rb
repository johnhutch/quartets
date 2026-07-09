FactoryBot.define do
  factory :report do
    association :puzzle, factory: :published_puzzle
    sequence(:reporter_token) { |n| "reporter-#{n}" }
    reason { "This category is unfair." }
    resolved { false }
  end
end
