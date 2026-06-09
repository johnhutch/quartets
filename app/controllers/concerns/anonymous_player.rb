# Anonymous, login-free identity for players. A signed, long-lived cookie so
# Phase 4 stats can attribute plays to a "player" without any account. Shared by
# every public surface that can be played from (home + the play pages).
module AnonymousPlayer
  extend ActiveSupport::Concern

  included do
    before_action :ensure_player_token
    helper_method :current_player_token
  end

  private

  def ensure_player_token
    cookies.signed.permanent[:player_token] ||= SecureRandom.uuid
  end

  def current_player_token
    cookies.signed[:player_token]
  end
end
