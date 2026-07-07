require "rails_helper"

# Account display names: asked at signup, editable in account settings, and the
# byline everywhere the owner has one — the puzzle's own free-text author_name
# is the fallback (and the whole story for anonymous authors).
RSpec.describe "Display names", type: :request do
  describe "signup + settings" do
    it "accepts a display name at signup" do
      post user_registration_path, params: {
        user: { email: "new@example.com", display_name: "Hutch",
                password: "password123", password_confirmation: "password123" }
      }

      expect(User.find_by(email: "new@example.com").display_name).to eq("Hutch")
    end

    it "asks for it on the signup and account-settings forms" do
      get new_user_registration_path
      expect(response.body).to include("user[display_name]")

      sign_in create(:user)
      get edit_user_registration_path
      expect(response.body).to include("user[display_name]")
    end
  end

  describe "byline precedence" do
    it "prefers the owner's display name over the puzzle's author_name" do
      user = create(:user, display_name: "The Real Hutch")
      puzzle = create(:published_puzzle, user: user, author_name: "Old Pen Name")

      get play_path(puzzle.share_token)

      expect(page_text).to include("The Real Hutch")
      expect(page_text).not_to include("Old Pen Name")
    end

    it "falls back to the puzzle's author_name when the owner has none" do
      user = create(:user, display_name: nil)
      puzzle = create(:published_puzzle, user: user, author_name: "Pen Name")

      get play_path(puzzle.share_token)

      expect(page_text).to include("Pen Name")
    end
  end

  describe "the authoring form's Author field" do
    it "disappears for a signed-in author with a display name" do
      sign_in create(:user, display_name: "Hutch")

      get new_puzzle_path

      expect(response.body).not_to include("[author_name]")
      expect(page_text).to include("Hutch") # the form says whose name it'll use
    end

    it "stays, with a settings nudge, for a signed-in author without one" do
      sign_in create(:user, display_name: nil)

      get new_puzzle_path

      expect(response.body).to include("[author_name]")
      expect(response.body).to include(edit_user_registration_path) # the nudge
    end

    it "stays, without the nudge, for anonymous authors" do
      get new_puzzle_path

      expect(response.body).to include("[author_name]")
      expect(response.body).not_to include(edit_user_registration_path)
    end
  end
end
