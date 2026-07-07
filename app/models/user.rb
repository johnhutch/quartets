class User < ApplicationRecord
  # Accounts are optional and public-facing now (ADR-0005): anyone can sign up to
  # own and revisit their puzzles. Registerable + recoverable for self-serve
  # signup and forgot-password; no confirmable (signup stays frictionless).
  # Trackable records sign-ins for the admin users tab.
  devise :database_authenticatable, :registerable, :recoverable,
         :rememberable, :validatable, :trackable

  has_many :puzzles, dependent: :destroy
  # Plays the account has recorded. Nullify on delete so the play still counts in
  # the puzzle's aggregate stats — it just goes back to anonymous (ADR-0009).
  has_many :attempts, dependent: :nullify

  # The public page slug (/u/:handle — the deferred D3 of ADR-0005). Minted from
  # the email's local part at signup, deduped with a numeric suffix. Stable: a
  # later email change doesn't touch it, so shared profile links keep working.
  before_validation :assign_handle, on: :create
  validates :handle, presence: true, uniqueness: true

  private

  def assign_handle
    return if handle.present?

    base = email.to_s.split("@").first.to_s.parameterize
    base = "player" if base.blank?
    candidate = base
    n = 1
    candidate = "#{base}-#{n += 1}" while self.class.exists?(handle: candidate)
    self.handle = candidate
  end
end
