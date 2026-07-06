FactoryBot.define do
  factory :puzzle do
    user
    sequence(:title) { |n| "Puzzle #{n}" }
    author_name { "Hutch" }
    status { :unlisted }

    # Adds the four correctly-colored groups a published puzzle needs. Words are
    # distinct across groups — sixteen different answers, like a real puzzle
    # (and required to publish).
    trait :complete do
      after(:build) do |puzzle|
        {
          blue:   %w[cat dog owl fox],
          green:  %w[one two three four],
          yellow: %w[mercury venus mars earth],
          purple: %w[piano drums bass flute]
        }.each_with_index do |(color, words), i|
          puzzle.groups << build(:group, puzzle: puzzle, color: color, words: words, position: i)
        end
      end
    end

    factory :published_puzzle, traits: [:complete] do
      status { :published }
    end
  end
end
