# /admin is staff-only (superuser or moderator). Signed-out visitors get the
# normal sign-in page (with a return-to, so staff on a fresh device land back
# here); signed-in non-staff get a 404, not a 403 — the area doesn't confirm
# what it is. The users tab tightens this to superuser-only
# (Admin::UsersController); the puzzles tab is open to both.
class Admin::BaseController < ApplicationController
  before_action :require_staff

  PER_PAGE = 10

  private

  def require_staff
    if !user_signed_in?
      store_location_for(:user, request.fullpath) if request.get?
      redirect_to new_user_session_path
    elsif !current_user.staff?
      head :not_found
    end
  end

  def require_superuser
    head :not_found unless user_signed_in? && current_user.superuser?
  end

  # Same dependency-free offset pagination as the owner dashboard.
  def paginate(scope)
    total = scope.count
    @total_pages = [(total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end
end
