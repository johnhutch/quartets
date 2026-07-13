require "rails_helper"

# The shared human/bot classifier — gates analytics so crawler traffic doesn't
# pollute the human funnels (and can be counted separately). Heuristic, on the UA.
RSpec.describe BotDetector do
  it "flags common search + AI crawlers" do
    [
      "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
      "Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)",
      "Mozilla/5.0 (compatible; GPTBot/1.2; +https://openai.com/gptbot)",
      "Mozilla/5.0 (compatible; ClaudeBot/1.0; +claudebot@anthropic.com)",
      "Mozilla/5.0 (compatible; PerplexityBot/1.0)",
      "facebookexternalhit/1.1",
      "curl/8.4.0"
    ].each do |ua|
      expect(BotDetector.bot?(ua)).to be(true), "expected bot: #{ua}"
    end
  end

  it "treats a real browser UA as human" do
    human = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 " \
            "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    expect(BotDetector.bot?(human)).to be(false)
  end

  it "treats a blank/absent UA as a bot (nothing legit hides its UA)" do
    expect(BotDetector.bot?(nil)).to be(true)
    expect(BotDetector.bot?("")).to be(true)
  end
end
