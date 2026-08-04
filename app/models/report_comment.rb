# A staff note on a report — append-only, stamped with its author. The triage
# page threads them under each report.
class ReportComment < ApplicationRecord
  belongs_to :report
  belongs_to :user

  validates :body, presence: true
end
