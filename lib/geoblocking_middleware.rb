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

    if info = DiscourseIpInfo.get(env['REMOTE_ADDR']).presence
      if country_code = info[:country_code].presence
        countries = SiteSetting.geoblocking_countries.upcase.split('|')
        return true if countries.include?(country_code.upcase)
      end
    end

    false
  end

  def is_static(path)
    return false if !path.present?

    path.starts_with?("#{GlobalSetting.relative_url_root}/assets/") ||
    path.starts_with?("#{GlobalSetting.relative_url_root}/images/") ||
    path.starts_with?("#{GlobalSetting.relative_url_root}/uploads/") ||
    path.starts_with?("#{GlobalSetting.relative_url_root}/stylesheets/")
  end
end
