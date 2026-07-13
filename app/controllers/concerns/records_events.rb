# Server-side funnel capture (analytics stream B). One-liner for controllers to
# drop a funnel Event, gated to humans (bots are counted elsewhere, not in the
# funnel) and fully best-effort — analytics must never break or slow a page. Needs
# AnonymousPlayer for the player_token.
module RecordsEvents
  private

  def record_event(event_type, puzzle: nil)
    return if BotDetector.bot?(request.user_agent)

    Event.create!(
      event_type: event_type,
      player_token: current_player_token,
      user: current_user,
      puzzle: puzzle
    )
  rescue StandardError
    nil # best-effort: a missed analytics write is invisible to the player
  end
end
