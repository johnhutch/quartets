class ApplicationController < ActionController::Base
  # Anonymous authors' puzzles get claimed onto their account the moment they
  # authenticate (ADR-0005).
  include ClaimsPuzzles

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Root is the public homepage now, so send a freshly signed-in author to their
  # dashboard instead of the visitor-facing front door.
  def after_sign_in_path_for(_resource)
    puzzles_path
  end
end
