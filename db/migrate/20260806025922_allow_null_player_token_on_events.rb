class AllowNullPlayerTokenOnEvents < ActiveRecord::Migration[8.1]
  # Sign-in events (session health) have no player to key off: Devise's own pages
  # don't include AnonymousPlayer, so someone who has never touched a play surface
  # has no player_token cookie to read. The play-funnel types still require one —
  # that's enforced in the model now rather than by the column.
  def change
    change_column_null :events, :player_token, true
  end
end
