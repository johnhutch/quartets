# Records a finished play. Anonymous and login-free — the attempt is tied to the
# player's cookie token so Phase 4 stats attribute without accounts. Best-effort:
# the game posts here on game over and ignores the response.
class AttemptsController < ApplicationController
  include AnonymousPlayer
  include Creator # owns? — owners can't record plays on their own puzzles

  # Public, login-free write — cap it so a script can't flood stats. Loose enough
  # that no real player ever trips it (keyed by IP; behind Cloudflare, see DEPLOY).
  rate_limit to: 30, within: 1.minute, only: :create, store: RATE_LIMIT_STORE

  def create
    # The same play gate as play#show (ADR-0008): any complete puzzle records,
    # listed or not; incomplete or unknown → 404 (nothing to play). Owners get
    # the same 404 — you don't play your own, so nothing to record. One rule,
    # one place (Playability).
    puzzle = Puzzle.find_by(share_token: params[:share_token])
    return head :not_found unless Playability.new(puzzle, owner: puzzle && owns?(puzzle)).playable?

    # Rebuild the play from the puzzle, not the client: solved/mistakes/colors are
    # all derived server-side, so a forged POST can't mint trophies or poison stats
    # (the endpoint is public and login-free). A log that isn't real puzzle words
    # is rejected, not sanitized.
    recording = PlayRecording.new(puzzle, attempt_params[:guesses], duration_ms: attempt_params[:duration_ms])
    return head :unprocessable_content unless recording.valid?

    # One recorded play per logged-in user (ADR-0009): a repeat POST just returns
    # their existing result instead of stacking duplicate attempts. Anonymous
    # plays are unchanged (player_token only).
    base = recording.attempt_attributes.merge(player_token: current_player_token)
    attempt =
      if user_signed_in?
        puzzle.attempts.find_by(user: current_user) || create_for(puzzle, base.merge(user: current_user))
      else
        puzzle.attempts.create!(base)
      end
    # The result payload the game injects: cube (on-screen grid), full share block
    # (title + cube + link, host from the request), the earned tier, and the
    # pre-rendered trophies block. PlayResult owns the shaping — the revisit view
    # builds the same one. ERB rendering stays here (PlayResult is a pure PORO).
    result = PlayResult.new(attempt, url: play_url(puzzle.share_token), viewer: current_user)
    awards = render_to_string(partial: "play/achievement", formats: [:html],
                              locals: result.awards_locals)
    # Rating buttons ride along for published puzzles (unlisted work isn't rated).
    rating = if puzzle.published?
      render_to_string(partial: "play/rating", formats: [:html],
                       locals: { puzzle: puzzle, attempt: attempt })
    end
    render json: { cube: result.cube, share: result.share, achievement: result.achievement, awards:, rating: },
           status: :created
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_content
  end

  private

  # The signed-in path races the partial unique (user_id, puzzle_id) index: two
  # near-simultaneous POSTs both miss the find_by, and the loser's insert raises
  # RecordNotUnique (which RecordInvalid doesn't cover). Re-find on the collision
  # so a double-fire returns the existing result instead of 500ing.
  def create_for(puzzle, attributes)
    puzzle.attempts.create!(attributes)
  rescue ActiveRecord::RecordNotUnique
    puzzle.attempts.find_by!(user: attributes[:user])
  end

  def attempt_params
    # solved/mistakes_count/colors are intentionally NOT permitted — the server
    # derives them from the puzzle (see PlayRecording). Only the ordered word
    # groups and timing come from the client.
    params.require(:attempt).permit(
      :duration_ms,
      # Each guess also carries `t` — ms since the game clock started — for
      # per-guess timing (the Guess value object reads it back).
      guesses: [:t, { words: [], colors: [] }]
    )
  end
end
