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
end
