require "rails_helper"

# WCAG 2.1 AA semantics that Lighthouse/axe can't fully automate (ADR-0012).
# Markup/role/name level only — contrast and prefers-reduced-motion are CSS and
# verified out-of-band via Lighthouse, not asserted here (they'd mean
# reimplementing colour math against compiled CSS — brittle, low value).
RSpec.describe "Accessibility", type: :system do
  describe "every page (2.4.1 Bypass Blocks, 1.3.1 landmarks)" do
    it "offers a skip link that targets the main landmark" do
      visit root_path

      expect(page).to have_link("Skip to main content", href: "#main")
      expect(page).to have_css("main#main")
    end

    it "names its navigation landmarks (4.1.2 Name, Role, Value)" do
      visit root_path

      # Multiple <nav>s (desktop + mobile) must each carry a distinct name.
      expect(page).to have_css("nav[aria-label]", minimum: 1)
      page.all("nav").each do |nav|
        expect(nav[:"aria-label"]).to be_present
      end
    end
  end

  describe "flash messages (4.1.3 Status Messages)" do
    it "exposes an errors flash as an assertive alert" do
      visit new_user_session_path
      fill_in "Email", with: "nobody@example.com"
      fill_in "Password", with: "wrong-password"
      click_button "Log in"

      expect(page).to have_css(".flash[role='alert']")
    end
  end

  describe "the authoring form (3.3.2 Labels, 4.1.2 Name)" do
    it "gives every answer input an accessible name, not just a placeholder" do
      visit new_puzzle_path

      # Four colours × four answers = sixteen inputs, each named "<Colour> answer N"
      # via aria-label (the placeholder alone isn't an accessible name).
      %w[Blue Green Yellow Purple].each do |colour|
        (1..4).each do |n|
          expect(page).to have_css(%(input[aria-label="#{colour} answer #{n}"]))
        end
      end
    end
  end
end
