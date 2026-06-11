# Public, login-free play. Everything here is open to the internet; the only
# gate is "published" — drafts stay invisible until their author ships them.
class PlayController < ApplicationController
  include AnonymousPlayer
  include Creator # for owns? — the owner gets a share prompt on their own puzzle

  def index
    @puzzles = Puzzle.published.order(created_at: :desc)
  end

  def show
    @puzzle = Puzzle.find_by!(share_token: params[:share_token])
    # Published puzzles are public; an unpublished one is visible only to its
    # owner, who lands here to preview + publish it (ADR-0005).
    head :not_found unless @puzzle.published? || owns?(@puzzle)
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
