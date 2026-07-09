require "rails_helper"

# The game posts a finished play here. Anonymous: the attempt is tied to the
# player's signed cookie token, no account needed. Any *complete* puzzle records,
# matching the play gate (ADR-0008) — incomplete ones (nothing to play) 404.
RSpec.describe "Attempts", type: :request do
  # The published_puzzle factory's real answers — the server validates submitted
  # guesses against these and derives colors/solved/mistakes from them.
  ANSWERS = {
    blue:   %w[cat dog owl fox],
    green:  %w[one two three four],
    yellow: %w[mercury venus mars earth],
    purple: %w[piano drums bass flute]
  }.freeze

  # A full winning log: each group cracked, in the given color order.
  def winning_guesses(order)
    order.map { |color| { words: ANSWERS.fetch(color.to_sym) } }
  end

  describe "POST /p/:share_token/attempts" do
    it "records a finished play, tied to the puzzle" do
      puzzle = create(:published_puzzle)

      expect {
        post play_attempts_path(puzzle.share_token), params: {
          attempt: {
            guesses: [
              { words: %w[cat dog owl one] },      # wrong — spans blue + green
              *winning_guesses(%i[blue green yellow purple])
            ]
          }
        }, as: :json
      }.to change(Attempt, :count).by(1)

      attempt = Attempt.last
      expect(response).to have_http_status(:created)
      expect(attempt.puzzle).to eq(puzzle)
      expect(attempt).to be_solved                      # derived, not asserted by client
      expect(attempt.mistakes_count).to eq(1)           # derived from the one wrong guess
      expect(attempt.player_token).to be_present
      expect(attempt.guesses.first["words"]).to eq(%w[cat dog owl one])
      expect(attempt.guesses.first["colors"]).to eq(%w[blue blue blue green]) # server-derived
    end

    it "ignores a client that lies about solving — colors come from the puzzle" do
      puzzle = create(:published_puzzle)

      post play_attempts_path(puzzle.share_token), params: {
        attempt: {
          solved: true, mistakes_count: 0, # client claims a flawless win…
          guesses: [{ words: %w[cat dog owl one], colors: %w[blue blue blue blue] }] # …on a wrong guess
        }
      }, as: :json

      attempt = Attempt.last
      expect(attempt).not_to be_solved
      expect(attempt.achievement).to be_nil # no forged trophy
      expect(attempt.guesses.first["colors"]).to eq(%w[blue blue blue green])
    end

    # Owners never play their own puzzles (Playability) — a POST from the owner
    # records nothing, so their trophies and stats can't be self-padded.
    it "refuses to record the owner playing their own puzzle" do
      user = create(:user)
      sign_in user
      puzzle = create(:published_puzzle, user: user)

      expect {
        post play_attempts_path(puzzle.share_token), params: {
          attempt: { solved: true, mistakes_count: 0 }
        }, as: :json
      }.not_to change(Attempt, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "returns the emoji cube for the just-finished play" do
      puzzle = create(:published_puzzle)

      post play_attempts_path(puzzle.share_token), params: {
        attempt: {
          guesses: [
            { words: %w[cat dog owl fox] }, # all blue
            { words: %w[cat dog owl one] }  # blue blue blue green
          ]
        }
      }, as: :json

      expect(response.parsed_body["cube"]).to eq("🟦🟦🟦🟦\n🟦🟦🟦🟩")
    end

    it "records the play timing — total duration and per-guess t" do
      puzzle = create(:published_puzzle)

      post play_attempts_path(puzzle.share_token), params: {
        attempt: {
          duration_ms: 18_500,
          guesses: [{ words: %w[cat dog owl fox], t: 4200 }]
        }
      }, as: :json

      attempt = Attempt.last
      expect(attempt.duration_ms).to eq(18_500)
      expect(attempt.guesses.first["t"]).to eq(4200)
      expect(attempt.guess_log.first.elapsed_ms).to eq(4200)
    end

    it "still records a play with no timing (older client, untimed)" do
      puzzle = create(:published_puzzle)

      post play_attempts_path(puzzle.share_token), params: {
        attempt: { guesses: [{ words: %w[cat dog owl fox] }] }
      }, as: :json

      attempt = Attempt.last
      expect(response).to have_http_status(:created)
      expect(attempt.duration_ms).to be_nil
      expect(attempt.guess_log.first.elapsed_ms).to be_nil
    end

    it "returns a full share block — title, cube, and a direct link to the puzzle" do
      puzzle = create(:published_puzzle, title: "Capital Cities")

      post play_attempts_path(puzzle.share_token), params: {
        attempt: { guesses: [{ words: %w[cat dog owl fox] }] }
      }, as: :json

      share = response.parsed_body["share"]
      expect(share).to include("Quartets — Capital Cities")
      expect(share).to include("🟦🟦🟦🟦")
      expect(share).to include(play_url(puzzle.share_token))
    end

    # ADR-0011: a flawless win earns a trophy; the response carries the tier and a
    # pre-rendered awards block (trophies + quip) the game injects. The order is the
    # solve order (drives the tier); each group is cracked with its real words.
    def flawless_win(order)
      { guesses: winning_guesses(order) }
    end

    it "returns the earned tier and an awards block on a flawless win" do
      puzzle = create(:published_puzzle)

      post play_attempts_path(puzzle.share_token),
           params: { attempt: flawless_win(%w[purple blue green yellow]) }, as: :json

      expect(response.parsed_body["achievement"]).to eq("reverse_rainbow")
      awards = response.parsed_body["awards"]
      expect(awards).to include("Reverse rainbow").and include("Purple first").and include("Perfect")
    end

    it "nudges an anonymous winner to sign up instead of showing a total" do
      puzzle = create(:published_puzzle)

      post play_attempts_path(puzzle.share_token),
           params: { attempt: flawless_win(%w[yellow green blue purple]) }, as: :json

      expect(response.parsed_body["awards"]).to include("Sign up")
      expect(response.parsed_body["awards"]).not_to include("That's your")
    end

    it "gives a signed-in winner a running total of their top trophy" do
      user = create(:user)
      sign_in user
      puzzle = create(:published_puzzle)

      post play_attempts_path(puzzle.share_token),
           params: { attempt: flawless_win(%w[purple green blue yellow]) }, as: :json

      expect(response.parsed_body["awards"]).to include("That's your 1st purple first")
    end

    it "carries a quip but no trophy on a loss" do
      puzzle = create(:published_puzzle)

      post play_attempts_path(puzzle.share_token),
           params: { attempt: { solved: false, mistakes_count: 4 } }, as: :json

      expect(response.parsed_body["achievement"]).to be_nil
      expect(response.parsed_body["awards"]).to include("m-awards__quip")
      expect(response.parsed_body["awards"]).not_to include("m-awards__trophies")
    end

    it "reuses the same player token across plays (the anonymous identity)" do
      puzzle = create(:published_puzzle)

      post play_attempts_path(puzzle.share_token),
           params: { attempt: { solved: false, mistakes_count: 4 } }, as: :json
      first_token = Attempt.last.player_token

      post play_attempts_path(puzzle.share_token),
           params: { attempt: { solved: true, mistakes_count: 0 } }, as: :json

      expect(Attempt.last.player_token).to eq(first_token)
    end

    it "records against a complete unlisted puzzle (shared by link)" do
      puzzle = create(:puzzle, :complete, status: :unlisted)

      expect {
        post play_attempts_path(puzzle.share_token),
             params: { attempt: { solved: true, mistakes_count: 0 } }, as: :json
      }.to change(Attempt, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "won't record against an incomplete puzzle — there's nothing to play" do
      puzzle = create(:puzzle, status: :unlisted) # no groups

      post play_attempts_path(puzzle.share_token),
           params: { attempt: { solved: true, mistakes_count: 0 } }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "404s an unknown token" do
      post play_attempts_path("nope"),
           params: { attempt: { solved: true, mistakes_count: 0 } }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "rejects a guess log with words that aren't in the puzzle (forgery/junk)" do
      puzzle = create(:published_puzzle)

      post play_attempts_path(puzzle.share_token), params: {
        attempt: { guesses: [{ words: %w[haxx spam junk lol] }] }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    context "when signed in (ADR-0009)" do
      it "attributes the attempt to the account" do
        user = create(:user)
        sign_in user
        puzzle = create(:published_puzzle)

        post play_attempts_path(puzzle.share_token),
             params: { attempt: { solved: true, mistakes_count: 0 } }, as: :json

        expect(Attempt.last.user).to eq(user)
      end

      it "records only one attempt per puzzle — a repeat POST is idempotent" do
        user = create(:user)
        sign_in user
        puzzle = create(:published_puzzle)

        expect {
          2.times do
            post play_attempts_path(puzzle.share_token),
                 params: { attempt: { solved: true, mistakes_count: 0 } }, as: :json
          end
        }.to change(Attempt, :count).by(1)

        expect(response).to have_http_status(:created)
      end
    end
  end
end
