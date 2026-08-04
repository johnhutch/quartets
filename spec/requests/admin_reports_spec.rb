require "rails_helper"

# The per-puzzle report triage page: the flag badge on the admin puzzles tab
# links here. A compact solved board + puzzle meta up top, open reports (each
# with a resolve-and/or-comment form) above resolved ones, which collapse to a
# one-line <details> summary.
RSpec.describe "Admin reports triage", type: :request do
  let(:moderator) { create(:user, :moderator, email: "mod@example.com", display_name: "Mod") }
  let(:puzzle) { create(:published_puzzle, title: "Sketchy One") }

  before { sign_in moderator }

  describe "GET /admin/puzzles/:puzzle_id/reports" do
    it "404s ordinary users" do
      sign_in create(:user)
      get admin_puzzle_reports_path(puzzle)
      expect(response).to have_http_status(:not_found)
    end

    it "shows the compact puzzle summary: groups, meta, action links" do
      get admin_puzzle_reports_path(puzzle)

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("Sketchy One") # multicolored title — assert text, not markup
      puzzle.groups.each do |group|
        expect(response.body).to include(group.description)
        expect(response.body).to include(ERB::Util.html_escape(group.filled_words.join(", ")))
      end
      expect(response.body).to include(play_path(puzzle.share_token))
      expect(response.body).to include(edit_puzzle_path(puzzle))
    end

    it "lists open reports with reporter, reason, and a resolve form" do
      report = create(:report, puzzle: puzzle, reason: "Answer overlap",
                      user: create(:user, display_name: "Snitch"))
      create(:report, puzzle: puzzle, reason: nil) # anonymous, no reason

      get admin_puzzle_reports_path(puzzle)

      expect(response.body).to include("Answer overlap")
      expect(response.body).to include("Snitch")
      expect(response.body).to include("anonymous")
      expect(response.body).to include(admin_report_path(report))
      expect(response.body).to include("WONTDO") # the resolution options
    end

    it "collapses resolved reports to a one-line summary below the open ones" do
      create(:report, puzzle: puzzle, reason: "Still open")
      resolved = create(:report, :resolved, puzzle: puzzle, reason: "Old news",
                        resolved_by: moderator)
      create(:report_comment, report: resolved, user: moderator, body: "Looked fine to me")

      get admin_puzzle_reports_path(puzzle)

      expect(response.body).to include("<details") # the fold-out
      expect(response.body.index("Still open")).to be < response.body.index("Old news")
      expect(response.body).to include("WONTDO") # the resolution chip
      expect(response.body).to include("Mod") # who resolved it
      expect(response.body).to include("Looked fine to me") # thread inside the fold-out
    end
  end

  describe "PATCH /admin/reports/:id" do
    let(:report) { create(:report, puzzle: puzzle) }

    it "resolves with a type, stamping who and when" do
      patch admin_report_path(report), params: { report: { resolution: "fixed" } }

      expect(report.reload).to be_fixed
      expect(report.resolved_by).to eq(moderator)
      expect(report.resolved_at).to be_present
      expect(response).to redirect_to(admin_puzzle_reports_path(puzzle))
    end

    it "adds a comment without resolving" do
      patch admin_report_path(report), params: { report: { comment: "waiting on the author" } }

      expect(report.reload.resolution).to be_nil
      expect(report.comments.sole.body).to eq("waiting on the author")
      expect(report.comments.sole.user).to eq(moderator)
    end

    it "does both in one submit" do
      patch admin_report_path(report), params: { report: { resolution: "willdo", comment: "on the list" } }

      expect(report.reload).to be_willdo
      expect(report.comments.sole.body).to eq("on the list")
    end

    it "re-resolves — WILLDO becomes FIXED with a fresh stamp" do
      report.update!(resolution: :willdo, resolved_at: 1.day.ago, resolved_by: create(:user, :superuser))

      patch admin_report_path(report), params: { report: { resolution: "fixed" } }

      expect(report.reload).to be_fixed
      expect(report.resolved_by).to eq(moderator)
      expect(report.resolved_at).to be > 1.hour.ago
    end

    it "rejects an empty submit — no resolution, no comment" do
      patch admin_report_path(report), params: { report: { resolution: "", comment: "  " } }

      expect(report.reload.resolution).to be_nil
      expect(report.comments).to be_empty
      expect(flash[:alert]).to match(/resolution or.*comment/i)
    end

    it "404s non-staff" do
      sign_in create(:user)
      patch admin_report_path(report), params: { report: { resolution: "fixed" } }
      expect(response).to have_http_status(:not_found)
      expect(report.reload.resolution).to be_nil
    end
  end

  describe "the flag badge" do
    it "links from the admin puzzles tab to the triage page" do
      create(:report, puzzle: puzzle)

      get admin_puzzles_path

      expect(response.body).to include(admin_puzzle_reports_path(puzzle))
    end
  end

  describe "bulk dismiss" do
    it "records the shortcut as WONTDO with the audit stamp" do
      create(:report, puzzle: puzzle)
      create(:report, puzzle: puzzle, reporter_token: "other")

      patch dismiss_reports_admin_puzzle_path(puzzle)

      expect(puzzle.reports.unresolved).to be_empty
      expect(puzzle.reports.pluck(:resolution).uniq).to eq(["wontdo"])
      expect(puzzle.reports.pluck(:resolved_by_id).uniq).to eq([moderator.id])
    end
  end
end
