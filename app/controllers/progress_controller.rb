# Saves an in-progress play (the mid-game counterpart of attempts#create) so a
# player can leave a puzzle and come back to the same board. Public and
# login-free like every play surface; the state is keyed by account when signed
# in, else by the player_token cookie. Best-effort from the game's side — a
# failed save never breaks the game, it just won't resume.
class ProgressController < ApplicationController
  include AnonymousPlayer
  include Creator # owns? — owners don't play (or save) their own puzzles

  # Public, login-free write — same cap as the attempts endpoint. An honest game
  # saves once per guess (eight max per play), so no real player gets near it.
  rate_limit to: 30, within: 1.minute, only: :update, store: RATE_LIMIT_STORE

  def update
    # Same play gate as play#show / attempts#create (ADR-0008): only a playable
    # puzzle saves, and the owner has nothing to save.
    puzzle = Puzzle.find_by(share_token: params[:share_token])
    return head :not_found unless Playability.new(puzzle, owner: puzzle && owns?(puzzle)).playable?

    # Same trust model as PlayRecording: the client asserts only the word
    # groups; colors are derived from the puzzle, junk words are rejected. A
    # *finished* log doesn't belong here — game over records via attempts#create
    # — so refusing it keeps a curl from parking a completed board as "progress".
    recording = PlayRecording.new(puzzle, progress_params[:guesses])
    return head :unprocessable_content unless recording.valid?
    return head :unprocessable_content if recording.solved? || recording.mistakes_count >= Puzzle::MAX_MISTAKES

    state = locate_state(puzzle)
    state.player_token ||= current_player_token
    state.update!(guesses: recording.guesses, elapsed_ms: progress_params[:elapsed_ms]&.to_i)
    head :no_content
  rescue ActiveRecord::RecordNotUnique
    # Two saves raced past the same find_or_initialize; the loser can drop its
    # write — the winner carried a log at most one guess apart.
    head :no_content
  end

  private

  # The same identity split as Attempt: the account when signed in (one saved
  # game per user per puzzle, any device), else the anonymous cookie token.
  def locate_state(puzzle)
    if user_signed_in?
      puzzle.play_states.find_or_initialize_by(user: current_user)
    else
      puzzle.play_states.where(user_id: nil).find_or_initialize_by(player_token: current_player_token)
    end
  end

  def progress_params
    # Only the ordered word groups + timing come from the client — colors and
    # correctness are server-derived (see PlayRecording).
    params.require(:progress).permit(:elapsed_ms, guesses: [:t, { words: [], colors: [] }])
  end
end
