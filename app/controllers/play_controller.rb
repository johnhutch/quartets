# Public, login-free play. Everything here is open to the internet. The index
# lists only published puzzles; an individual board is playable as soon as it's
# complete, listed or not (ADR-0008) — "published" only controls visibility.
class PlayController < ApplicationController
  include AnonymousPlayer
  include Creator # for owns? — the owner gets a share prompt on their own puzzle

  PER_PAGE = 24

  def index
    # Which of these the signed-in player has already finished, for the check.
    @completed_ids = user_signed_in? ? current_user.attempts.distinct.pluck(:puzzle_id).to_set : Set.new

    # Filters, GET params only (nothing persists): "hide my puzzles" defaults
    # ON — you can't play your own (Playability), so they're noise here — and
    # covers anonymous authors via their creator_token cookie (ADR-0005);
    # "hide completed" defaults OFF — finished ones stay visible but dimmed.
    @hide_mine = params[:hide_mine] != "0"
    @hide_completed = params[:hide_completed] == "1"

    scope = Puzzle.published.includes(:user, :tags).order(created_at: :desc)
    scope = scope.not_owned_by(user: current_user, creator_token: current_creator_token) if @hide_mine
    scope = scope.where.not(id: @completed_ids.to_a) if @hide_completed && @completed_ids.any?

    # Paginate so the archive doesn't load + aggregate the whole catalog per hit
    # as it grows (the NAS is a slow box). Plain offset, same as the dashboard.
    total = scope.count
    @total_pages = [(total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @puzzles = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE).load

    # One grouped query for the page's vote aggregates (keyed by id; unrated
    # puzzles get no entry and render nothing).
    @rating_summaries = RatingSummary.for(@puzzles)
  end

  def show
    @puzzle = Puzzle.find_by(share_token: params[:share_token])

    # The play gate (ADR-0008): a complete puzzle plays for anyone with the link
    # (published or just unlisted); an incomplete one effectively doesn't exist —
    # its owner is bounced to the editor, everyone else (and unknown tokens) 404.
    # The owner of a complete puzzle doesn't play it (they know the answers —
    # no self-earned trophies or stats): they see the board revealed.
    case Playability.new(@puzzle, owner: @puzzle && owns?(@puzzle)).status
    when :editable then return redirect_to(edit_puzzle_path(@puzzle))
    when :missing  then return head(:not_found)
    when :owned    then @owned_view = true
    end

    # The crowd's verdict, shown under the byline (owners see it on their own
    # puzzle too — it's their feedback).
    @rating_summary = RatingSummary.for_puzzle(@puzzle)

    # One play per player (ADR-0009, ADR-0012): once they've finished a puzzle,
    # show the reconstructed finished board instead of a fresh one. Logged-in
    # players are keyed by account; anonymous players by their player_token
    # (best-effort — clearing the cookie still lets a stranger replay, fine).
    @my_attempt = finished_attempt unless @owned_view
  end

  private

  def finished_attempt
    if user_signed_in?
      current_user.attempts.find_by(puzzle: @puzzle)
    else
      @puzzle.attempts.where(player_token: current_player_token).order(created_at: :desc).first
    end
  end
end
