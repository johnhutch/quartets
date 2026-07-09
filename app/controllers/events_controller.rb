# Records the `game_started` beacon the game fires on the first tile tap. This is
# the only way to know a game began — nothing else hits the server between the
# play page load and the game-over POST — so it's what makes started→finished
# funnels and abandon detection possible later (derived against Attempt). Same
# gate and anonymous identity as attempts#create: any complete puzzle records,
# tied to the player's cookie token. Best-effort: the game ignores the response.
class EventsController < ApplicationController
  include AnonymousPlayer
  include Creator # owns? — an owner's own play shouldn't skew the started funnel

  # Beacon endpoint, public and login-free — cap it so it can't be flooded.
  rate_limit to: 30, within: 1.minute, only: :create, store: RATE_LIMIT_STORE

  def create
    puzzle = Puzzle.find_by(share_token: params[:share_token])
    return head :not_found unless Playability.new(puzzle, owner: puzzle && owns?(puzzle)).playable?

    puzzle.events.create!(
      event_type: :game_started,
      player_token: current_player_token,
      user: current_user
    )
    head :created
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_content
  end
end
