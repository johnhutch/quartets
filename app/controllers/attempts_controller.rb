# Records a finished play. Anonymous and login-free — the attempt is tied to the
# player's cookie token so Phase 4 stats attribute without accounts. Best-effort:
# the game posts here on game over and ignores the response.
class AttemptsController < ApplicationController
  include AnonymousPlayer
  include Creator # owns? — owners can't record plays on their own puzzles

  def create
    # The same play gate as play#show (ADR-0008): any complete puzzle records,
    # listed or not; incomplete or unknown → 404 (nothing to play). Owners get
    # the same 404 — you don't play your own, so nothing to record. One rule,
    # one place (Playability).
    puzzle = Puzzle.find_by(share_token: params[:share_token])
    return head :not_found unless Playability.new(puzzle, owner: puzzle && owns?(puzzle)).playable?

    # One recorded play per logged-in user (ADR-0009): a repeat POST just returns
    # their existing result instead of stacking duplicate attempts. Anonymous
    # plays are unchanged (player_token only).
    base = attempt_params.merge(player_token: current_player_token)
    attempt =
      if user_signed_in?
        puzzle.attempts.find_by(user: current_user) || puzzle.attempts.create!(base.merge(user: current_user))
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
    render json: { cube: result.cube, share: result.share, achievement: result.achievement, awards: },
           status: :created
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_content
  end

  private

  def attempt_params
    params.require(:attempt).permit(
      :solved,
      :mistakes_count,
      :duration_ms,
      # Each guess also carries `t` — ms since the game clock started — for
      # per-guess timing (the Guess value object reads it back).
      guesses: [:t, { words: [], colors: [] }]
    )
  end
end
