require "rails_helper"

# Anyone viewing a puzzle can flag it for staff review. Login-free (anonymous
# players carry a token), deduped one-per-reporter, and it emails staff on a new
# flag so a bad puzzle doesn't sit unnoticed after a public launch.
RSpec.describe "Reports", type: :request do
  describe "POST /p/:share_token/reports" do
    it "flags a puzzle and thanks the reporter" do
      puzzle = create(:published_puzzle)

      expect {
        post play_reports_path(puzzle.share_token), params: { reason: "Offensive" }
      }.to change(Report, :count).by(1)

      report = Report.last
      expect(report.puzzle).to eq(puzzle)
      expect(report.reason).to eq("Offensive")
      expect(report.reporter_token).to be_present
      expect(response).to redirect_to(play_path(puzzle.share_token))
      follow_redirect!
      expect(response.body).to include("flagged")
    end

    it "emails staff when a new flag comes in" do
      puzzle = create(:published_puzzle)

      expect {
        post play_reports_path(puzzle.share_token), params: { reason: "spam" }
      }.to have_enqueued_mail(AdminMailer, :puzzle_reported)
    end

    it "dedupes a repeat flag from the same reporter (and doesn't re-email)" do
      puzzle = create(:published_puzzle)

      post play_reports_path(puzzle.share_token) # first flag (same cookie jar)
      expect {
        expect {
          post play_reports_path(puzzle.share_token)
        }.not_to change(Report, :count)
      }.not_to have_enqueued_mail(AdminMailer, :puzzle_reported)
    end

    it "404s an unknown puzzle" do
      post play_reports_path("nope")
      expect(response).to have_http_status(:not_found)
    end
  end
end
