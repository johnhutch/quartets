FactoryBot.define do
  factory :play_state do
    association :puzzle, factory: :published_puzzle
    user { nil }
    player_token { SecureRandom.uuid }
    guesses { [{ "words" => %w[cat dog owl fox], "colors" => %w[blue blue blue blue], "t" => 1000 }] }
    elapsed_ms { 5_000 }
  end
end
