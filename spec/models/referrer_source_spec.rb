require "rails_helper"

# Classifies where a visit came from, off the Referer header — the key to the
# GEO/AEO requirement: an "ai" segment for traffic sent by answer engines.
RSpec.describe ReferrerSource do
  it "calls a blank referrer direct" do
    expect(ReferrerSource.classify(nil)).to eq(:direct)
    expect(ReferrerSource.classify("")).to eq(:direct)
  end

  it "segments AI answer engines" do
    %w[
      https://chatgpt.com/ https://www.perplexity.ai/search
      https://claude.ai/chat https://gemini.google.com/app
      https://copilot.microsoft.com/
    ].each { |r| expect(ReferrerSource.classify(r)).to eq(:ai), "expected ai: #{r}" }
  end

  it "segments search engines" do
    %w[https://www.google.com/ https://www.bing.com/search https://duckduckgo.com/]
      .each { |r| expect(ReferrerSource.classify(r)).to eq(:search), "expected search: #{r}" }
  end

  it "segments social" do
    %w[https://www.reddit.com/r/nytconnections https://bsky.app/ https://t.co/abc]
      .each { |r| expect(ReferrerSource.classify(r)).to eq(:social), "expected social: #{r}" }
  end

  it "calls anything else other" do
    expect(ReferrerSource.classify("https://someblog.example/post")).to eq(:other)
  end
end
