# Parses the old Obsidian Connections archive and imports it. The archive is
# hand-maintained and inconsistent — heading levels swing ##–####, color case
# varies, some groups use markdown bullets and others plain lines, and a few
# blocks are unfinished junk. So the parser is forgiving and normalizes on the
# way in; the importer publishes complete 4×4 puzzles, salvages partial ones as
# drafts (don't lose work), and skips blocks with no group structure.
#
# Parsing is pure (and hard-spec'd); persistence is idempotent (keyed on title).
class ObsidianArchive
  COLORS = Group.colors.keys.freeze # %w[blue green yellow purple]

  def self.parse(markdown)
    new(markdown).parse
  end

  # Returns { published:, unlisted:, skipped: } — arrays of titles.
  def self.import(markdown, user:)
    summary = { published: [], unlisted: [], skipped: [] }

    parse(markdown).each do |data|
      groups = data[:groups]

      if groups.empty? || user.puzzles.exists?(title: data[:title])
        summary[:skipped] << data[:title]
        next
      end

      puzzle = build_puzzle(data, groups, user)
      puzzle.save!
      (puzzle.published? ? summary[:published] : summary[:unlisted]) << data[:title]
    end

    summary
  end

  def self.build_puzzle(data, groups, user)
    puzzle = user.puzzles.build(title: data[:title], author_name: "Imported from Obsidian")
    groups.each_with_index do |group, i|
      puzzle.groups.build(
        color: group[:color],
        description: group[:description],
        words: group[:words],
        position: i
      )
    end
    puzzle.status = complete?(groups) ? :published : :unlisted
    puzzle
  end
  private_class_method :build_puzzle

  # Ready to publish: all four distinct colors, each with a category and 4 words.
  def self.complete?(groups)
    return false unless groups.size == COLORS.size
    return false unless groups.map { |g| g[:color] }.sort == COLORS.sort

    groups.all? { |g| g[:words].size == Group::WORDS_PER_GROUP && g[:description].present? }
  end
  private_class_method :complete?

  def initialize(markdown)
    @lines = markdown.to_s.lines.map(&:chomp)
  end

  def parse
    @puzzles = []
    @puzzle = nil
    @group = nil

    @lines.each { |raw| consume(raw.strip) }
    @puzzles
  end

  private

  def consume(line)
    return if line.empty? || line.start_with?("http")

    if line.start_with?("#")
      consume_heading(line)
    elsif @group
      consume_content(line)
    end
  end

  def consume_heading(line)
    hashes = line[/\A#+/].length
    text = line.sub(/\A#+\s*/, "").strip

    if hashes == 1
      @puzzle = { title: text, groups: [] }
      @puzzles << @puzzle
      @group = nil
    elsif @puzzle && (color = normalize_color(text))
      @group = { color: color, description: nil, words: [] }
      @puzzle[:groups] << @group
    else
      @group = nil # an unrecognized sub-heading ends the current group
    end
  end

  # The first content line under a group header is the category, the second its
  # words. Anything further is ignored.
  def consume_content(line)
    text = clean(line)
    if @group[:description].nil?
      @group[:description] = text
    elsif @group[:words].empty?
      @group[:words] = split_words(text)
    end
  end

  def normalize_color(text)
    color = text.strip.downcase
    color if COLORS.include?(color)
  end

  # Strip a leading list bullet ("* "/"- ") and trailing markdown italics ("*").
  def clean(line)
    line.sub(/\A[*\-]\s+/, "").sub(/\s*\*+\z/, "").strip
  end

  def split_words(text)
    text.split(",").map(&:strip).reject(&:blank?)
  end
end
