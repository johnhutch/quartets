class PuzzlesController < ApplicationController
  include Creator

  # Creation is public (ADR-0005) — no authenticate_user!. Ownership is by
  # account when signed in, else by the creator_token cookie we mint here.
  before_action :ensure_creator_token
  before_action :set_puzzle, only: %i[edit update publish unpublish destroy stats export]

  PER_PAGE = 10

  def index
    # eager-load groups — the row template calls complete? on each puzzle.
    scope = owned_puzzles.includes(:groups).order(updated_at: :desc, id: :desc)
    @puzzles_total = scope.count
    @total_pages = [(@puzzles_total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @puzzles = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  # Author analytics for one puzzle — how it's playing out in the wild.
  def stats
    @stats = PuzzleStats.new(@puzzle.attempts)
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
  end

  def create
    @puzzle = owned_puzzles.build(puzzle_params)

    if @puzzle.save
      # Auto-save's first POST creates the record; hand the editor URL back in
      # the Location header so the controller can switch to PATCH from here on.
      if autosave?
        group_ids = @puzzle.groups.to_h { |g| [g.color, g.id] }
        render json: { patch_url: puzzle_path(@puzzle), group_ids: group_ids }, 
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

  # Flip a draft to published. The full 4×4 structural rules fire here.
  def publish
    @puzzle.status = :published

    if @puzzle.save
      # Land on the live puzzle with the celebratory "it's published!" banner
      # (?published=1 distinguishes the just-published moment from a later visit).
      redirect_to play_path(@puzzle.share_token, published: 1)
    else
      @puzzle.status = :draft # keep it a draft; just show what's missing
      flash.now[:alert] = "Can't publish yet — fix the issues below."
      ensure_four_groups
      render :edit, status: :unprocessable_content
    end
  end

  # Pull a published puzzle back to draft — hides it from the public play surfaces
  # while the author reworks it. Lenient draft rules apply again.
  def unpublish
    @puzzle.update!(status: :draft)
    redirect_to puzzles_path, notice: "Unpublished — back to a draft."
  end

  def destroy
    @puzzle.destroy
    redirect_to puzzles_path, notice: "Puzzle deleted."
  end

  private

  # Scoped to the requester — by account or creator_token — so one author can
  # never reach another's work.
  def set_puzzle
    @puzzle = owned_puzzles.find(params[:id])
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
      groups_attributes: [:id, :color, :description, { words: [] }]
    )
  end

  # The form always shows all four colored blocks, even on a sparse old draft.
  def ensure_four_groups
    present = @puzzle.groups.map { |g| g.color&.to_sym }
    Group.colors.keys.each_with_index do |color, i|
      @puzzle.groups.build(color: color, position: i) unless present.include?(color.to_sym)
    end
  end
end
