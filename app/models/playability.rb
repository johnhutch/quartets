# The play gate (ADR-0008). Given the looked-up puzzle (nil for an unknown token)
# and whether the viewer owns it, answers whether it's playable — and if not, why.
# One definition the play page (`play#show`) and the attempt recorder
# (`attempts#create`) share, instead of each mirroring the rule.
#
# Owners never play their own puzzles — they know the answers, so a play would
# just pad their trophies and pollute the puzzle's stats. Their own board shows
# revealed (:owned) instead.
class Playability
  def initialize(puzzle, owner: false)
    @puzzle = puzzle
    @owner = owner
  end

  # Playable iff it exists, is complete (visibility is irrelevant — ADR-0008),
  # and isn't the viewer's own. The recorder gates on this, so owner attempts
  # never record.
  def playable?
    (@puzzle&.complete? && !@owner) || false
  end

  # :playable, or why not: :owned (complete, but it's yours — shown revealed),
  # :editable (incomplete, but the owner can finish it), or :missing (unknown
  # token, or incomplete to a stranger — it doesn't exist yet).
  def status
    return :missing unless @puzzle
    return :playable if playable?
    return :owned if @owner && @puzzle.complete?

    @owner ? :editable : :missing
  end
end
