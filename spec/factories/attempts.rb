FactoryBot.define do
  factory :attempt do
    association :puzzle, factory: :published_puzzle
    sequence(:player_token) { |n| "player-#{n}" }
    solved { false }
    mistakes_count { 0 }
    guesses { [] }
  end
end
