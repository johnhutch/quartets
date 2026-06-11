require "rails_helper"

# The public account flows (ADR-0005): sign up, log in, log out, and the
# forgot-password handoff. Server-rendered Devise forms — no JS needed.
RSpec.describe "Authentication", type: :system do
  it "lets a visitor sign up and land logged in on their dashboard" do
    visit new_user_registration_path

    fill_in "Email", with: "newbie@example.com"
    fill_in "Password", with: "correct-horse-battery"
    fill_in "Confirm password", with: "correct-horse-battery"
    click_button "Sign up"

    expect(page).to have_current_path(puzzles_path)
    expect(page).to have_button("Log out")
    expect(User.find_by(email: "newbie@example.com")).to be_present
  end

  it "logs an existing user in and back out" do
    create(:user, email: "back@example.com", password: "correct-horse-battery")

    visit new_user_session_path
    fill_in "Email", with: "back@example.com"
    fill_in "Password", with: "correct-horse-battery"
    click_button "Log in"

    expect(page).to have_current_path(puzzles_path)
    expect(page).to have_button("Log out")

    click_button "Log out"

    expect(page).to have_link("Log in")
    expect(page).to have_no_button("Log out")
  end

  it "walks the forgot-password request from the login screen" do
    create(:user, email: "lost@example.com")

    visit new_user_session_path
    click_link "Forgot your password?"
    expect(page).to have_current_path(new_user_password_path)

    fill_in "Email", with: "lost@example.com"
    click_button "Send reset instructions"

    # Devise confirms the handoff without leaking whether the address exists.
    expect(page).to have_content(/receive an email|reset/i)
  end
end
