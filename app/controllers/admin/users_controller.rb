# The users tab: every account, with last sign-in (Devise trackable), puzzles
# created, and puzzles solved. Counts come from two grouped queries over the
# page's users — no N+1, no counter caches.
class Admin::UsersController < Admin::BaseController
  def index
    @users = paginate(User.order(created_at: :desc))
    ids = @users.map(&:id)
    @created_counts = Puzzle.where(user_id: ids).group(:user_id).count
    @solved_counts = Attempt.where(user_id: ids, solved: true)
                            .group(:user_id).distinct.count(:puzzle_id)
  end
end
