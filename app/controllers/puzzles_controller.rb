class PuzzlesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_puzzle, only: %i[edit update publish destroy]

  def index
    @puzzles = current_user.puzzles.order(updated_at: :desc)
  end

  def new
    @puzzle = current_user.puzzles.build
    ensure_four_groups
  end

  def create
    @puzzle = current_user.puzzles.build(puzzle_params)

    if @puzzle.save
      # Auto-save's first POST creates the record; hand the editor URL back in
      # the Location header so the controller can switch to PATCH from here on.
      if autosave?
        head :created, location: edit_puzzle_path(@puzzle)
      else
        redirect_to edit_puzzle_path(@puzzle), notice: "Draft saved."
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
        redirect_to edit_puzzle_path(@puzzle), notice: "Saved."
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
      redirect_to puzzles_path, notice: "Published — ready to share."
    else
      @puzzle.status = :draft # keep it a draft; just show what's missing
      flash.now[:alert] = "Can't publish yet — fix the issues below."
      ensure_four_groups
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @puzzle.destroy
    redirect_to puzzles_path, notice: "Puzzle deleted."
  end

  private

  # Scoped to the current user, so one superuser can never reach another's work.
  def set_puzzle
    @puzzle = current_user.puzzles.find(params[:id])
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
