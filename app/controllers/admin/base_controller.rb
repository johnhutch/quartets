# Everything under /admin is superuser-only. Everyone else gets a 404, not a
# 403 — the area shouldn't advertise its existence.
class Admin::BaseController < ApplicationController
  before_action :require_superuser

  PER_PAGE = 10

  private

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
