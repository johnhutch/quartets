# Records a finished play. Anonymous and login-free — the attempt is tied to the
# player's cookie token so Phase 4 stats attribute without accounts. Best-effort:
# the game posts here on game over and ignores the response.
class AttemptsController < ApplicationController
  include AnonymousPlayer

  def create
    # Mirror the play gate (ADR-0008): any complete puzzle records, listed or not.
    # Incomplete (or unknown) → 404, same as the play page — nothing to play.
    puzzle = Puzzle.find_by(share_token: params[:share_token])
    return head :not_found unless puzzle&.complete?

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
    # Hand back the cube (for the on-screen grid) and the full share block — title
    # + cube + a direct link — so the just-finished game can show one and copy the
    # other. play_url uses the request host, so the share link follows whatever
    # domain we're served on.
    cube = EmojiCube.new(attempt.guesses).to_s
    share = ShareText.new(title: puzzle.title, cube:, url: play_url(puzzle.share_token)).to_s
    render json: { cube:, share: }, status: :created
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_content
  end

  private

  def attempt_params
    params.require(:attempt).permit(
      :solved,
      :mistakes_count,
      guesses: [:correct, { words: [], colors: [] }]
    )
  end
end
