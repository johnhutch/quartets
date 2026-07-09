require "rails_helper"

# The public, login-free write endpoints are rate-limited so a script can't flood
# stats/votes/puzzles (review finding). Limits count in the shared cache; the test
# env's null_store never counts, so we swap in a real store for these examples.
RSpec.describe "Rate limiting", type: :request do
  around do |example|
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
    Rails.cache = original
  end

  it "429s the tag autocomplete once the per-minute cap is passed" do
    61.times { get tags_path(q: "star") }
    expect(response).to have_http_status(:too_many_requests)
  end

  it "429s attempt recording past the cap" do
    puzzle = create(:published_puzzle)

    31.times do
      post play_attempts_path(puzzle.share_token),
           params: { attempt: { guesses: [] } }, as: :json
    end

    expect(response).to have_http_status(:too_many_requests)
  end

  it "leaves a normal number of requests alone" do
    get tags_path(q: "star")
    expect(response).to have_http_status(:ok)
  end
end
