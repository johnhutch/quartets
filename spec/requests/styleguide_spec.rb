require "rails_helper"

RSpec.describe "Style guide", type: :request do
  it "is public and renders the brutalist reference" do
    get "/styleguide"

    expect(response).to have_http_status(:ok)
    expect(response).not_to redirect_to(new_user_session_path)
    expect(response.body).to include("theme-brutal")     # the scoped theme is on
    expect(response.body).to include("brutalist system")  # plain lede copy
    expect(response.body).to include("u-ink--")           # multicolor spans rendered
    expect(response.body).to include("m-card")            # tile components shown
  end
end
