# frozen_string_literal: true

class GeoblockingMiddleware
  def initialize(app, _options = {})
    @app = app
  end

  def call(env)
    if check_route(env) && is_blocked(env)
      GeoblockingController.action('blocked').call(env)
    else
      @app.call(env)
    end
  end

  private

  def check_route(env)
    ['srv/status', '/admin'].each do |route|
      return false if env["REQUEST_URI"].include?(route)
    end

    true
  end

  def is_blocked(env)
    return false if !SiteSetting.geoblocking_enabled || is_static(env['REQUEST_PATH'])

    whitelist = SiteSetting.geoblocking_whitelist&.upcase
    default_blocked = SiteSetting.geoblocking_use_whitelist && whitelist.present?
    request = Rack::Request.new(env)

    info = DiscourseIpInfo.get(request.ip).presence
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
