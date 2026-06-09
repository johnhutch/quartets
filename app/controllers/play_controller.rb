# Public, login-free play. Everything here is open to the internet; the only
# gate is "published" — drafts stay invisible until their author ships them.
class PlayController < ApplicationController
  include AnonymousPlayer

  def index
    @puzzles = Puzzle.published.order(created_at: :desc)
  end

  def show
    @puzzle = Puzzle.published.find_by!(share_token: params[:share_token])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
