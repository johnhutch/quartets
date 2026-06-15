class User < ApplicationRecord
  # Accounts are optional and public-facing now (ADR-0005): anyone can sign up to
  # own and revisit their puzzles. Registerable + recoverable for self-serve
  # signup and forgot-password; no confirmable (signup stays frictionless).
  devise :database_authenticatable, :registerable, :recoverable,
         :rememberable, :validatable

  has_many :puzzles, dependent: :destroy
  # Plays the account has recorded. Nullify on delete so the play still counts in
  # the puzzle's aggregate stats — it just goes back to anonymous (ADR-0009).
  has_many :attempts, dependent: :nullify
end
