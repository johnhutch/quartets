# Post-play ratings, on the attempt (one finished play = one vote, logged-in or
# anonymous alike). Null = hasn't rated. Quality is positive-only (yeah /
# hell-yeah); difficulty runs pretty-easy → @!#?@!.
class AddRatingsToAttempts < ActiveRecord::Migration[8.1]
  def change
    add_column :attempts, :quality, :integer
    add_column :attempts, :difficulty, :integer
  end
end
