# Post-play rating (quality / difficulty), written onto the viewer's attempt —
# one finished play, one vote, re-rating overwrites. Published puzzles only;
# anonymous players rate through the same cookie token their attempt carries.
class RatingsController < ApplicationController
  include AnonymousPlayer

  # Public write — capped so votes can't be scripted en masse.
  rate_limit to: 30, within: 1.minute, only: :update, store: RATE_LIMIT_STORE

  def update
    puzzle = Puzzle.find_by(share_token: params[:share_token])
    return head :not_found unless puzzle&.published?

    attempt = find_attempt(puzzle)
    return head :not_found unless attempt

    attempt.update!(rating_params)
    head :no_content
  rescue ArgumentError # a value that isn't on the enum menu
    head :unprocessable_content
  end

  private

  # Same viewer→attempt resolution as the revisit view (play#show).
  def find_attempt(puzzle)
    if user_signed_in?
      current_user.attempts.find_by(puzzle: puzzle)
    else
      puzzle.attempts.where(player_token: current_player_token).order(created_at: :desc).first
    end
  end

  def rating_params
    params.permit(:quality, :difficulty).to_h.slice("quality", "difficulty").compact
  end
end
