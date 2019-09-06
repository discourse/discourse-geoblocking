# frozen_string_literal: true

class GeoblockingMiddleware
  def initialize(app, _options = {})
    @app = app
  end

  def call(env)
    if is_blocked(env)
      GeoblockingController.action('blocked').call(env)
    else
      @app.call(env)
    end
  end

  private

  def is_blocked(env)
    return false if !SiteSetting.geoblocking_enabled || is_static(env['REQUEST_PATH'])

    request = Rack::Request.new(env)
    if info = DiscourseIpInfo.get(request.ip).presence
      if country_code = info[:country_code].presence
        return true if SiteSetting.geoblocking_countries.upcase[country_code.upcase]
      end
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
