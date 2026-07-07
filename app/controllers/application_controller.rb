class ApplicationController < ActionController::Base
  # Anonymous authors' puzzles get claimed onto their account the moment they
  # authenticate (ADR-0005).
  include ClaimsPuzzles

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Devise's default permit list doesn't know our extra column; display_name is
  # asked at signup and editable in account settings.
  before_action :configure_devise_params, if: :devise_controller?

  # Root is the public homepage now, so send a freshly signed-in author to their
  # dashboard instead of the visitor-facing front door.
  def after_sign_in_path_for(_resource)
    puzzles_path
  end

  private

  def configure_devise_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [:display_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:display_name])
  end
end
