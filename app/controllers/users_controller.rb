# Public per-creator page (/u/:handle — the deferred D3 of ADR-0005). Shows only
# what's already public: published puzzles and account-scoped play stats. No
# login required, same as every play surface.
class UsersController < ApplicationController
  def show
    @user = User.find_by(handle: params[:handle]) or return head(:not_found)
    @puzzles = @user.puzzles.published.order(created_at: :desc).to_a
    @play_counts = play_counts_for(@puzzles) # one grouped query, not per-row counts
    # Created counts published work only — drafts and unlisted stay private.
    @stats = PlayerStats.new(attempts: @user.attempts, created: @puzzles.size)
  end
end
