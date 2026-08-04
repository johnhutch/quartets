# A player flagging a puzzle for staff review (spam, offensive, broken). One per
# reporter per puzzle (unique index) so a repeat flag doesn't inflate the count.
# Staff triage them at /admin/puzzles/:id/reports: a resolution types the call
# (NULL = still open) with a who/when stamp, and comments hold the paper trail.
class Report < ApplicationRecord
  belongs_to :puzzle
  belongs_to :user, optional: true # anonymous reporters carry only a token
  belongs_to :resolved_by, class_name: "User", optional: true
  has_many :comments, class_name: "ReportComment", dependent: :destroy

  validates :reporter_token, presence: true

  enum :resolution, { fixed: 0, willdo: 1, wontdo: 2, duplicate: 3 }

  scope :unresolved, -> { where(resolution: nil) }

  def resolved? = resolution.present?

  # One writer for the audit stamp — a re-resolution (WILLDO → FIXED) restamps.
  def resolve!(resolution, by:)
    update!(resolution: resolution, resolved_at: Time.current, resolved_by: by)
  end
end
