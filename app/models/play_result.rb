# The payload shown after a finished play (ADR-0011): the emoji cube, the full
# share block, the earned trophy tier, and the locals for the trophies-block
# partial. One owner so attempts#create (the JSON the game injects) and the revisit
# view (play/_result) stop each re-deriving it. Pure value object; the play URL is
# handed in so the host follows the request, like ShareText. `viewer` is the
# current account (or nil when anonymous) and decides total-vs-nudge.
class PlayResult
  def initialize(attempt, url:, viewer:)
    @attempt = attempt
    @url = url
    @viewer = viewer
  end

  def cube
    @cube ||= EmojiCube.new(@attempt.guess_log).to_s
  end

  def share
    ShareText.new(title: @attempt.puzzle.title, cube: cube, url: @url).to_s
  end

  def achievement
    @attempt.achievement
  end

  # Locals for the play/achievement partial (trophies + quip + total/nudge). A
  # signed-in winner gets a running count of their top trophy; anonymous players
  # can't (uncapped attempts → farmable) and fall through to the sign-up nudge.
  def awards_locals
    { attempt: @attempt, total: total, signed_in: @viewer.present? }
  end

  private

  def total
    top = @attempt.earned_tiers.last
    @viewer.attempts.at_least(top).count if @viewer && top
  end
end
