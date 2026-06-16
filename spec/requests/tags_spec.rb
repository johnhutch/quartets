require "rails_helper"

# Autocomplete source for the authoring tag combobox.
RSpec.describe "Tags suggest", type: :request do
  describe "GET /tags?q=" do
    it "returns existing tag names matching the (normalized) query" do
      Tag.create!(name: "star-wars")
      Tag.create!(name: "star-trek")
      Tag.create!(name: "marvel")

      get tags_path(q: "Star")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to contain_exactly("star-wars", "star-trek")
    end

    it "normalizes the query so 'Star Wars' still matches 'star-wars'" do
      Tag.create!(name: "star-wars")

      get tags_path(q: "Star Wars")

      expect(response.parsed_body).to include("star-wars")
    end

    it "returns an empty list for a blank query" do
      Tag.create!(name: "marvel")

      get tags_path(q: "")

      expect(response.parsed_body).to eq([])
    end
  end
end
