# frozen_string_literal: true

class GeoblockingMiddleware
  STATIC_PATHS ||= %w[assets/ images/ uploads/ stylesheets/ service-worker/]

  ALLOWED_PATHS ||= %w[
    srv/status
    u/admin-login
    users/admin-login
    session/email-login
    session/csrf
    logs/report_js_error
    manifest.webmanifest
  ]

  def initialize(app, _options = {})
    @app = app
  end

  def call(env)
    if SiteSetting.geoblocking_enabled && is_blocked?(env)
      GeoblockingController.action("blocked").call(env)
    else
      @app.call(env)
    end
  end

  private

  def is_admin?(env)
    CurrentUser.lookup_from_env(env)&.admin?
  rescue Discourse::InvalidAccess, Discourse::ReadOnly
    false
  end

  def absolute_path(path)
    File.join("/", GlobalSetting.relative_url_root.to_s, path)
  end

  def starts_with_any?(string, prefixes)
    string.starts_with?(*prefixes.map { |prefix| absolute_path(prefix) })
  end

  def matches_any?(string, paths)
    paths.any? { |path| string == absolute_path(path) }
  end

  def is_static?(path)
    path.present? && starts_with_any?(path, STATIC_PATHS)
  end

  def is_allowed?(path)
    return false if path.blank?

    matches_any?(path, ALLOWED_PATHS) ||
      matches_any?(path, SiteSetting.geoblocking_allowed_paths.split("|"))
  end

  def is_blocked?(env)
    return false if is_admin?(env)
    return false if is_static?(env["PATH_INFO"])
    return false if is_allowed?(env["PATH_INFO"])

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
end
