require "rails_helper"

# The Sentry initializer is DSN-gated so error reporting never turns on in dev,
# test, or an un-configured production — nothing phones home until the NAS .env
# sets SENTRY_DSN. This pins that guard: a green CI run must not ship events.
RSpec.describe "Sentry error monitoring" do
  it "stays dormant in the test environment (no DSN, no reporting)" do
    expect(ENV["SENTRY_DSN"]).to be_blank
    expect(Sentry.initialized?).to be(false)
  end

  it "initializes with PII off, prod-only, and our noise exclusions when a DSN is set" do
    original = ENV["SENTRY_DSN"]
    ENV["SENTRY_DSN"] = "https://public@o0.ingest.sentry.io/123"
    load Rails.root.join("config/initializers/sentry.rb")

    config = Sentry.get_current_client.configuration
    expect(config.send_default_pii).to be(false)          # no user data leaves the box
    expect(config.enabled_environments).to eq(%w[production])
    expect(config.excluded_exceptions).to include("ActionController::RoutingError")
  ensure
    Sentry.close # reset so the dormancy spec (and everything else) sees it off
    ENV["SENTRY_DSN"] = original
  end
end
