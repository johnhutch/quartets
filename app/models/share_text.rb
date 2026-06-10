# The full block a finished player copies to brag — the puzzle title, the emoji
# cube, and a direct link back. The cube alone is just squares; this is what
# actually gets pasted into a text. Pure value object: the URL is handed in so
# the host comes from the request (whatever domain we land on), never a hardcode.
class ShareText
  def initialize(title:, cube:, url:)
    @title = title
    @cube = cube
    @url = url
  end

  def to_s
    ["Quartets — #{@title}", @cube, @url].join("\n\n")
  end
end
