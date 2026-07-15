require "rails_helper"

# The PWA manifest makes the site installable as a standalone home-screen app
# (iOS/Android add-to-home-screen), so it opens chrome-less with our name + icon.
RSpec.describe "PWA manifest", type: :request do
  it "serves the manifest as JSON with the app's identity" do
    get pwa_manifest_path(format: :json)

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["name"]).to eq("Quartets")
    expect(body["display"]).to eq("standalone")
    expect(body["icons"]).to be_present
  end

  it "links the manifest from the page head" do
    get root_path
    expect(response.body).to include('rel="manifest"')
  end

  it "serves the service worker as JavaScript" do
    # Browsers register a SW with Accept: */* (not text/html), so match that.
    get pwa_service_worker_path, headers: { "HTTP_ACCEPT" => "*/*" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/javascript")
    expect(response.body).to include("addEventListener") # a real SW, not a stub
  end

  it "reserves the status bar (black, not translucent) so content stays in the safe area" do
    get root_path
    expect(response.body).to include('name="apple-mobile-web-app-status-bar-style" content="black"')
  end
end
