class User < ApplicationRecord
  # Superuser-only. No public registration, no email-based recovery —
  # just a login for the one admin who creates puzzles.
  devise :database_authenticatable, :rememberable, :validatable

  has_many :puzzles, dependent: :destroy
end
