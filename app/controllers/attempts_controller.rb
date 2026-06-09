# Records a finished play. Anonymous and login-free — the attempt is tied to the
# player's cookie token so Phase 4 stats attribute without accounts. Best-effort:
# the game posts here on game over and ignores the response.
class AttemptsController < ApplicationController
  include AnonymousPlayer

  def create
    puzzle = Puzzle.published.find_by!(share_token: params[:share_token])
    attempt = puzzle.attempts.create!(attempt_params.merge(player_token: current_player_token))
    # Hand the cube back so the just-finished game can show + copy it.
    render json: { cube: EmojiCube.new(attempt.guesses).to_s }, status: :created
  rescue ActiveRecord::RecordNotFound
    head :not_found
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
