# Where a visit came from, classified off the Referer header. The `ai` segment is
# the GEO/AEO payoff — traffic sent by answer engines (ChatGPT, Perplexity, …) —
# which is exactly what the robots.txt invites those crawlers to do.
module ReferrerSource
  AI     = /chatgpt|openai|perplexity|claude\.ai|anthropic|gemini\.google|bard\.google|copilot|you\.com|phind/i
  SEARCH = /google\.|bing\.|duckduckgo|yahoo\.|yandex|baidu|ecosia|brave/i
  SOCIAL = /reddit|bsky|bluesky|t\.co|twitter|x\.com|facebook|instagram|linkedin|mastodon|tumblr|threads/i

  def self.classify(referrer)
    ref = referrer.to_s.strip
    return :direct if ref.empty?
    return :ai if ref.match?(AI)
    return :search if ref.match?(SEARCH)
    return :social if ref.match?(SOCIAL)

    :other
  end
end
