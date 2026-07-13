# Shared human/bot classifier for analytics — a UA heuristic, so crawler traffic
# doesn't pollute the human funnels (stream B) and can be counted on its own
# (stream A). Not security; just "is this a person or a machine." A blank UA
# counts as a bot — real browsers always send one.
module BotDetector
  # Crawlers, scrapers, social unfurlers, AI bots, and headless/CLI agents. Broad
  # on purpose — a false "bot" only drops one analytics row, never affects a user.
  PATTERN = /
    bot|crawl|spider|slurp|scrape|
    google|bing|yandex|duckduck|baidu|sogou|
    facebookexternalhit|meta-externalagent|slackbot|discordbot|telegrambot|
    whatsapp|twitterbot|linkedinbot|pinterest|redditbot|embedly|quora|
    gptbot|chatgpt|oai-searchbot|claudebot|claude-|anthropic|perplexity|
    ccbot|bytespider|amazonbot|applebot|
    ahrefs|semrush|mj12|dotbot|dataforseo|
    headless|phantom|puppeteer|playwright|
    curl|wget|python-requests|python-httpx|go-http-client|libwww|okhttp
  /ix

  def self.bot?(user_agent)
    ua = user_agent.to_s.strip
    return true if ua.empty?

    PATTERN.match?(ua)
  end
end
