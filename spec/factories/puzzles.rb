FactoryBot.define do
  factory :puzzle do
    user
    sequence(:title) { |n| "Puzzle #{n}" }
    author_name { "Hutch" }
    status { :unlisted }

    # Adds the four correctly-colored groups a published puzzle needs.
    trait :complete do
      after(:build) do |puzzle|
        %i[blue green yellow purple].each_with_index do |color, i|
          puzzle.groups << build(:group, puzzle: puzzle, color: color, position: i)
        end
      end
    end

    factory :published_puzzle, traits: [:complete] do
      status { :published }
    end
  end
end
