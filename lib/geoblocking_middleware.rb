# frozen_string_literal: true

class GeoblockingMiddleware
  def initialize(app, _options = {})
    @app = app
  end

  def call(env)
    if SiteSetting.geoblocking_enabled && not_admin(env) && check_route(env) && is_blocked(env)
      GeoblockingController.action("blocked").call(env)
    else
      @app.call(env)
    end
  end

  private

  def not_admin(env)
    user = CurrentUser.lookup_from_env(env)
    user.nil? || !user.admin?
  rescue Discourse::InvalidAccess, Discourse::ReadOnly
    true
  end

  def check_route(env)
    return false if is_static(env["REQUEST_PATH"])

    %w[
      srv/status
      u/admin-login
      users/admin-login
      session/email-login
      session/csrf
      logs/report_js_error
      manifest.webmanifest
    ].each { |route| return false if env["REQUEST_URI"].include?(route) }

    true
  end

  def is_blocked(env)
    default_blocked =
      SiteSetting.geoblocking_allowed_countries.present? ||
        SiteSetting.geoblocking_allowed_geoname_ids.present?
    request = Rack::Request.new(env)

    info = DiscourseIpInfo.get(request.ip)
    return default_blocked if info.blank?

    country_code = info[:country_code]&.upcase
    geoname_ids = info[:geoname_ids] || []
    return default_blocked if country_code.blank? && geoname_ids.blank?

    if default_blocked
      if !DiscourseGeoblocking.allowed_countries.include?(country_code) &&
           !geoname_ids.any? { |id| DiscourseGeoblocking.allowed_geoname_ids.include?(id) }
        return true
      end
    else
      if DiscourseGeoblocking.blocked_countries.include?(country_code) ||
           geoname_ids.any? { |id| DiscourseGeoblocking.blocked_geoname_ids.include?(id) }
        return true
      end
    end

    false
  end

  def is_static(path)
    return false if path.blank?

    path.starts_with?("#{GlobalSetting.relative_url_root}/assets/") ||
      path.starts_with?("#{GlobalSetting.relative_url_root}/images/") ||
      path.starts_with?("#{GlobalSetting.relative_url_root}/uploads/") ||
      path.starts_with?("#{GlobalSetting.relative_url_root}/stylesheets/") ||
      path.starts_with?("#{GlobalSetting.relative_url_root}/service-worker")
  end
end
