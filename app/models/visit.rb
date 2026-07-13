# A first-party page-view log (analytics stream A). One row per human/bot page
# request — path + referrer + user-agent, NO IP and NO cookie, so it's standard
# server-side logging, not cross-site tracking (keeps the privacy promise). Bots
# are flagged (BotDetector) and counted separately from humans.
class Visit < ApplicationRecord
  attribute :occurred_at, default: -> { Time.current }

  # Classify the referrer once, at write time, so the dashboard groups in SQL.
  before_validation { self.source = ReferrerSource.classify(referrer).to_s }

  validates :path, presence: true

  scope :humans, -> { where(bot: false) }
  scope :bots, -> { where(bot: true) }
end
