# A player flagging a puzzle for staff review (spam, offensive, broken). One per
# reporter per puzzle (unique index) so a repeat flag doesn't inflate the count.
# Staff act on them from the admin puzzles tab; resolving means "handled" —
# whether that was a takedown or a "this is fine, dismiss."
class Report < ApplicationRecord
  belongs_to :puzzle
  belongs_to :user, optional: true # anonymous reporters carry only a token

  validates :reporter_token, presence: true

  scope :unresolved, -> { where(resolved: false) }
end
