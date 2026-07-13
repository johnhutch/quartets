class PuzzlesController < ApplicationController
  include Creator
  include AnonymousPlayer # player_token, for the authoring-funnel event
  include RecordsEvents

  # Creation is public (ADR-0005) — no authenticate_user!. Ownership is by
  # account when signed in, else by the creator_token cookie we mint here.
  before_action :ensure_creator_token, unless: :user_signed_in?
  before_action :set_puzzle, only: %i[edit update publish unpublish destroy restore stats export]

  # Creation is public, so cap new-puzzle POSTs — generous (autosave mints one
  # record then PATCHes, so a real authoring session is a single create) but
  # enough to stop a script spawning puzzles. Autosave PATCHes aren't limited.
  rate_limit to: 10, within: 15.minutes, only: :create, store: RATE_LIMIT_STORE

  PER_PAGE = 10

  def index
    # eager-load groups — the row template calls complete? on each puzzle.
    scope = owned_puzzles.includes(:groups).order(updated_at: :desc, id: :desc)
    @puzzles_total = scope.count
    @total_pages = [(@puzzles_total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @puzzles = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    @play_counts = play_counts_for(@puzzles)
    # Trophy case + play stats for the "Your stuff" top block (ADR-0011). Account-
    # scoped: an anonymous author only gets the created count + a sign-up nudge.
    @stats = PlayerStats.new(attempts: (current_user.attempts if user_signed_in?),
                             created: @puzzles_total)
    # Author-side reach: how all their puzzles are doing out in the world.
    # Puzzle-scoped (not account-scoped), so anonymous authors get it too.
    @author_stats = AuthorStats.for(owned_puzzles)
  end

  # Author analytics for one puzzle — how it's playing out in the wild.
  def stats
    @stats = PuzzleStats.new(@puzzle.attempts)
    @rating = RatingSummary.for_puzzle(@puzzle)
  end

  # Download the puzzle as portable JSON (stable schema — see PuzzleExport).
  def export
    serializer = PuzzleExport.new(@puzzle)
    send_data serializer.to_json,
              type: :json,
              filename: serializer.filename,
              disposition: "attachment"
  end

  def new
    @puzzle = owned_puzzles.build
    ensure_four_groups
    record_event(:authoring_opened) # funnel: reached the create form
  end

  def create
    @puzzle = owned_puzzles.build(puzzle_params)

    if @puzzle.save
      # Auto-save's first POST creates the record; hand the editor URL back in
      # the Location header so the controller can switch to PATCH from here on.
      if autosave?
        group_ids = @puzzle.groups.to_h { |g| [g.color, g.id] }
        # publish_url lets the just-minted form reveal + wire its Publish button
        # without a reload (the button needs an id, which only exists now).
        render json: { patch_url: puzzle_path(@puzzle), publish_url: publish_puzzle_path(@puzzle), group_ids: group_ids },
               status: :created,
               location: edit_puzzle_path(@puzzle)
      else
        # "Save draft" / "Finish" drops the author back on their dashboard.
        redirect_to puzzles_path
      end
    else
      ensure_four_groups
      render :new, status: :unprocessable_content
    end
  end

  def edit
    ensure_four_groups
  end

  def update
    if @puzzle.update(puzzle_params)
      # A background auto-save stays invisible: no redirect, no flash. The user
      # keeps typing while the draft quietly lands.
      if autosave?
        head :no_content
      else
        # A manual save drops the author back on their dashboard.
        redirect_to puzzles_path
      end
    else
      ensure_four_groups
      render :edit, status: :unprocessable_content
    end
  end

  # Flip an unlisted puzzle to published. The full 4×4 structural rules fire here.
  def publish
    @puzzle.status = :published

    if @puzzle.save
      # Land on the live puzzle with the celebratory "it's published!" banner
      # (?published=1 distinguishes the just-published moment from a later visit).
      redirect_to play_path(@puzzle.share_token, published: 1)
    else
      @puzzle.status = :unlisted # keep it unlisted; just show what's missing
      flash.now[:alert] = "Can't publish yet — fix the issues below."
      ensure_four_groups
      render :edit, status: :unprocessable_content
    end
  end

  # Pull a published puzzle back to unlisted — off the public play surfaces, but
  # the link still works — while the author reworks it. Lenient rules apply again.
  def unpublish
    @puzzle.update!(status: :unlisted)
    redirect_to puzzles_path, notice: "Made unlisted — the link still works, just not listed."
  end

  def destroy
    # Hybrid (ADR): a played puzzle is tombstoned so its attempts — and every
    # player's trophies/stats derived from them — survive; an unplayed one (an
    # abandoned draft, mostly) hard-deletes to keep the table clean.
    if @puzzle.attempts.exists?
      @puzzle.soft_delete!
      redirect_to puzzles_path, notice: "Puzzle deleted. Players' stats are kept."
    else
      @puzzle.destroy
      redirect_to puzzles_path, notice: "Puzzle deleted."
    end
  end

  # Superuser-only in practice: a normal owner's scope is kept-only, so their
  # set_puzzle can't even find a tombstoned puzzle (404). The admin's
  # accessible_puzzles is with_deleted, so this reaches a deleted one.
  def restore
    @puzzle.restore!
    redirect_back fallback_location: admin_puzzles_path, notice: "Puzzle restored."
  end

  private

  # Scoped to the requester — by account or creator_token — so one author can
  # never reach another's work. Staff (superuser or moderator) pass on everything
  # for moderation (the /admin puzzles tab hands them owner-grade action rows).
  def set_puzzle
    @puzzle = accessible_puzzles.find(params[:id])
  end

  def accessible_puzzles
    # Staff reach every puzzle, tombstones included (so they can moderate:
    # unpublish, delete, restore). Owners get their kept-only scope — a deleted
    # puzzle 404s for them, which is what gates restore to staff.
    user_signed_in? && current_user.staff? ? Puzzle.with_deleted : owned_puzzles
  end

  # Background draft saves flag themselves so we answer quietly instead of
  # redirecting with a flash.
  def autosave?
    params[:autosave].present?
  end

  def puzzle_params
    params.require(:puzzle).permit(
      :title,
      :author_name,
      :description,
      :specialized,
      tag_names: [],
      groups_attributes: [:id, :color, :position, :description, { words: [] }]
    )
  end

  # Authoring/form block order: easiest → hardest (yellow → green → blue → purple),
  # the NYT difficulty order. The form sorts its blocks by this (see _form), so a
  # color swap reorders on the next load — not the enum's stored integers
  # (blue:0…purple:3) or the shuffled board.
  FORM_COLOR_ORDER = %w[yellow green blue purple].freeze

  # The form always shows all four colored blocks, even on a sparse old draft.
  def ensure_four_groups
    present = @puzzle.groups.map { |g| g.color&.to_sym }
    FORM_COLOR_ORDER.each_with_index do |color, i|
      @puzzle.groups.build(color: color, position: i) unless present.include?(color.to_sym)
    end
  end
end
