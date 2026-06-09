# The portable JSON representation of a puzzle — a stable, documented schema for
# download/backup/interop (mirrors the shape the importer and engine speak).
# Pure serializer; the schema is pinned by its spec, so change it on purpose.
class PuzzleExport
  def initialize(puzzle)
    @puzzle = puzzle
  end

  def to_h
    {
      "title"  => @puzzle.title,
      "author" => @puzzle.author_name,
      "groups" => @puzzle.groups.map do |group|
        {
          "color"       => group.color,
          "description" => group.description,
          "words"       => Array(group.words)
        }
      end
    }
  end

  def to_json(*)
    JSON.generate(to_h)
  end

  def filename
    slug = @puzzle.title.to_s.parameterize.presence || "puzzle"
    "#{slug}.json"
  end
end
