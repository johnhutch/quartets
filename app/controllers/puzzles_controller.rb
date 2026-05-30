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
      redirect_to edit_puzzle_path(@puzzle), notice: "Draft saved."
    else
      ensure_four_groups
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    ensure_four_groups
  end

  def update
    if @puzzle.update(puzzle_params)
      redirect_to edit_puzzle_path(@puzzle), notice: "Saved."
    else
      ensure_four_groups
      render :edit, status: :unprocessable_entity
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
      render :edit, status: :unprocessable_entity
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
