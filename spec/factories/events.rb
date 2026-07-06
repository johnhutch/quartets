FactoryBot.define do
  factory :event do
    association :puzzle, factory: :published_puzzle
    event_type { :game_started }
    sequence(:player_token) { |n| "player-#{n}" }
    # occurred_at is left to the model default (attribute :occurred_at).
  end
end
