# frozen_string_literal: true

# name: discourse-geoblocking
# about: Restricts access to content based upon the user's geographical location (IP location).
# version: 0.1
# url: https://github.com/discourse-org/discourse-geoblocking


after_initialize do
  require_dependency "application_controller"

  class ActionController::Base
    def geoblock
      if check_route(request) && is_blocked(request)
        respond_to do |format|
          if SiteSetting.geoblocking_blocked_redirect.present?
            format.html do
              redirect_to SiteSetting.geoblocking_blocked_redirect
            end
          else
            format.html do
              append_view_path(File.expand_path("../app/views", __FILE__))
              render 'geoblocking/blocked', layout: 'no_ember', locals: { hide_auth_buttons: true }, status: :forbidden
            end
          end
          format.json do
            render json: { errors: [I18n.t('geoblocking.blocked')] }
          end
          format.all do
            head :forbidden
          end
        end
      end
    end

    private

    def check_route(request)
      ['srv/status', '/admin'].each do |route|
        return false if request.path.include?(route)
      end

      true
    end

    def is_blocked(request)
      return false if !SiteSetting.geoblocking_enabled || is_static(request.path)

      whitelist = SiteSetting.geoblocking_whitelist&.upcase
      default_blocked = SiteSetting.geoblocking_use_whitelist && whitelist.present?

      info = DiscourseIpInfo.get(request.remote_ip).presence
      return default_blocked if !info

      country_code = info[:country_code].presence
      return default_blocked if !country_code

      if SiteSetting.geoblocking_use_whitelist
        return false if !whitelist.present?
        return true if !whitelist[country_code.upcase]
      else
        return true if SiteSetting.geoblocking_countries.upcase[country_code.upcase]
      end

      false
    end

    def is_static(path)
      return false if path.blank?

      path.starts_with?("#{GlobalSetting.relative_url_root}/assets/") ||
      path.starts_with?("#{GlobalSetting.relative_url_root}/images/") ||
      path.starts_with?("#{GlobalSetting.relative_url_root}/uploads/") ||
      path.starts_with?("#{GlobalSetting.relative_url_root}/stylesheets/")
    end
  end
  ActionController::Base.instance_eval { before_action :geoblock }
end

