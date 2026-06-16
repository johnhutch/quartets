# The play gate (ADR-0008). Given the looked-up puzzle (nil for an unknown token)
# and whether the viewer owns it, answers whether it's playable — and if not, why.
# One definition the play page (`play#show`) and the attempt recorder
# (`attempts#create`) share, instead of each mirroring the rule.
class Playability
  def initialize(puzzle, owner: false)
    @puzzle = puzzle
    @owner = owner
  end

  # Playable iff it exists and is complete — visibility is irrelevant (ADR-0008).
  # Owner-agnostic, so the recorder can gate without an ownership check.
  def playable?
    @puzzle&.complete? || false
  end

  # :playable, or why not: :editable (incomplete, but the owner can finish it) or
  # :missing (unknown token, or incomplete to a stranger — it doesn't exist yet).
  def status
    return :missing unless @puzzle
    return :playable if playable?

    @owner ? :editable : :missing
  end
end
