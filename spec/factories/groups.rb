FactoryBot.define do
  factory :group do
    puzzle
    color { :blue }
    sequence(:description) { |n| "Category #{n}" }
    words { %w[alpha bravo charlie delta] }
    sequence(:position) { |n| n }
  end
end
