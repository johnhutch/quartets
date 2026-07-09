# Reconstructs a finished play from what the client is *allowed* to assert — the
# ordered word-groups the player submitted — and derives everything else (each
# word's true color, which guesses were correct, mistakes, whether it's solved)
# from the puzzle itself. The recording endpoint is public and login-free, so the
# client can't be trusted with `solved`/`mistakes_count`/`colors`: those would let
# a curl POST mint trophies and poison stats. Here the server owns them.
#
# Invalid input (a guess that isn't four real puzzle words, or an implausibly long
# log) is rejected outright rather than sanitized — an honest game never sends it.
class PlayRecording
  # An honest game submits at most one guess per group plus MAX_MISTAKES misses.
  MAX_GUESSES = Puzzle::GROUPS_PER_PUZZLE + Puzzle::MAX_MISTAKES

  def initialize(puzzle, raw_guesses, duration_ms: nil)
    @puzzle = puzzle
    @raw = Array(raw_guesses)
    @duration_ms = duration_ms
  end

  def valid?
    errors.empty?
  end

  def errors
    @errors ||= collect_errors
  end

  # The guess log to persist: the submitted words with server-derived colors and
  # the client's per-guess timing (timing can't farm trophies, so it rides as-is).
  def guesses
    @guesses ||= @raw.map do |raw|
      words = word_list(raw)
      { "words" => words, "colors" => words.map { |w| color_of(w) }, "t" => timing(raw) }
    end
  end

  def solved?
    solved_colors.uniq.size == Puzzle::GROUPS_PER_PUZZLE
  end

  # Wrong guesses, capped at the game's mistake limit (an honest game stops there).
  def mistakes_count
    [guesses.count { |g| wrong?(g) }, Puzzle::MAX_MISTAKES].min
  end

  def attempt_attributes
    { solved: solved?, mistakes_count: mistakes_count, duration_ms: @duration_ms, guesses: guesses }
  end

  private

  # Word (downcased) → color name, from the puzzle's real groups.
  def color_map
    @color_map ||= @puzzle.groups.each_with_object({}) do |group, map|
      group.filled_words.each { |w| map[w.downcase] = group.color }
    end
  end

  def color_of(word)
    color_map[word.to_s.strip.downcase]
  end

  def word_list(raw)
    Array(raw[:words] || raw["words"]).map { |w| w.to_s.strip }
  end

  def timing(raw)
    t = raw[:t] || raw["t"]
    t&.to_i
  end

  def wrong?(guess)
    guess["colors"].uniq.size > 1
  end

  # The color each correct guess found, in solve order (drives the trophy tier).
  def solved_colors
    guesses.filter_map do |g|
      colors = g["colors"]
      colors.first if colors.any? && colors.uniq.size == 1
    end
  end

  def collect_errors
    errors = []
    errors << "too many guesses" if @raw.size > MAX_GUESSES
    guesses.each do |guess|
      words = guess["words"]
      if words.size != Group::WORDS_PER_GROUP
        errors << "a guess must be #{Group::WORDS_PER_GROUP} words"
      elsif guess["colors"].any?(&:nil?)
        errors << "a guess used words that aren't in this puzzle"
      end
    end
    errors
  end
end
