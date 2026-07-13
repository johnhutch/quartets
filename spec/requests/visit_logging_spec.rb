require "rails_helper"

# The site-wide page-view logger (analytics stream A) — server-side, no IP, no
# cookie. Logs successful HTML GETs; skips assets/admin/infra and flags bots.
RSpec.describe "Visit logging", type: :request do
  BROWSER_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 " \
               "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1".freeze

  it "logs a human page view with its classified source" do
    expect {
      get play_index_path, headers: { "HTTP_REFERER" => "https://chatgpt.com/", "HTTP_USER_AGENT" => BROWSER_UA }
    }.to change(Visit, :count).by(1)

    visit = Visit.last
    expect(visit.path).to eq(play_index_path)
    expect(visit.source).to eq("ai")
    expect(visit).not_to be_bot
  end

  it "flags a crawler as a bot" do
    get root_path, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (compatible; GPTBot/1.2)" }
    expect(Visit.last).to be_bot
  end

  it "doesn't log admin, infra, or non-GET paths" do
    su = create(:user, :superuser)
    sign_in su

    expect {
      get admin_puzzles_path # staff browsing isn't traffic
      get "/up"              # health check
      get "/sitemap.xml"     # crawler infra
    }.not_to change(Visit, :count)
  end

  it "stores no IP or cookie — just path, referrer, UA" do
    get play_index_path
    expect(Visit.column_names).not_to include("ip", "ip_address", "player_token")
  end
end
