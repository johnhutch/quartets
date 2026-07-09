require "rails_helper"

RSpec.describe AdminMailer, type: :mailer do
  describe "#puzzle_reported" do
    it "goes to every staff member with the puzzle title and reason" do
      create(:user, :superuser, email: "boss@example.com")
      create(:user, :moderator, email: "mod@example.com")
      create(:user, email: "nobody@example.com") # not staff — excluded
      puzzle = create(:published_puzzle, title: "Sketchy One")
      report = create(:report, puzzle: puzzle, reason: "Offensive category")

      mail = described_class.puzzle_reported(report)

      expect(mail.to).to contain_exactly("boss@example.com", "mod@example.com")
      expect(mail.subject).to include("Sketchy One")
      expect(mail.body.encoded).to include("Offensive category")
    end

    it "doesn't send when there are no staff to notify" do
      report = create(:report)
      mail = described_class.puzzle_reported(report)
      expect(mail.to).to be_blank
    end
  end
end
