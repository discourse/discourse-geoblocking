# frozen_string_literal: true

class GeoblockingController < ApplicationController
  skip_before_action :check_xhr, :preload_json, :redirect_to_login_if_required

  def blocked
    respond_to do |format|
      if SiteSetting.geoblocking_blocked_redirect.present?
        format.html { redirect_to SiteSetting.geoblocking_blocked_redirect, allow_other_host: true }
      else
        format.html do
          append_view_path(File.expand_path("../../views", __FILE__))
          render :blocked,
                 layout: "no_ember",
                 locals: {
                   hide_auth_buttons: true,
                 },
                 status: :forbidden
        end
      end
      format.json { render json: { errors: [I18n.t("geoblocking.blocked")] }, status: :forbidden }
      format.all { head :forbidden }
    end
  end
end
