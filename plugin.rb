# frozen_string_literal: true

# name: discourse-geoblocking
# about: Restricts access to content based upon the user's geographical location (IP location).
# version: 0.1
# url: https://github.com/discourse-org/discourse-geoblocking

enabled_site_setting :geoblocking_enabled

require_relative("lib/geoblocking_middleware")

DiscourseEvent.on(:after_initializers) do
  # Must be added after DebugExceptions so that postgres errors trigger failover
  middleware =
    if defined?(Logster::Middleware::DebugExceptions)
      Logster::Middleware::DebugExceptions
    else
      ActionDispatch::DebugExceptions
    end

  Rails.configuration.middleware.insert_after(middleware, GeoblockingMiddleware)
end

after_initialize do
  require_relative("app/controllers/geoblocking_controller")
end
