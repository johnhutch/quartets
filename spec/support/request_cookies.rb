# Shared request-spec helpers for the anonymous-identity cookies (ADR-0024/0025):
# reading a cookie's expiry off the response, and getting at the player_token the
# way the server sees it. Included for `type: :request`, same as PageText.
module RequestCookies
  # The raw Set-Cookie line for a cookie. Rack can hand these back as one
  # newline-joined string or as an array depending on version, hence the flatten.
  def set_cookie_line(name)
    Array(response.headers["Set-Cookie"]).flat_map { |header| header.split("\n") }
                                         .find { |line| line.start_with?("#{name}=") }
  end

  # A line with no `expires=` is a session cookie — the browser drops it on close.
  def expiry_of(name)
    line = set_cookie_line(name)
    return nil if line.nil?

    stamp = line[/expires=([^;]+)/i, 1]
    stamp && Time.parse(stamp)
  end

  # BotDetector counts a blank user agent as a crawler and request specs send
  # none, so anything that leans on funnel events has to look like a browser.
  def browser_headers
    { "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Safari/605.1" }
  end

  # The visitor's player_token as the *server* sees it. The cookie is signed with
  # its expiry baked into the payload, so the bytes change every request and can't
  # be compared directly — but play#show logs a puzzle_opened event keyed by the
  # token, which can.
  def play_anonymously(puzzle)
    get play_path(puzzle.share_token), headers: browser_headers
    Event.puzzle_opened.last.player_token
  end
end

RSpec.configure do |config|
  config.include RequestCookies, type: :request
end
