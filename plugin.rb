# frozen_string_literal: true

# name: discourse-geoblocking
# about: Restricts access to content based upon the user's geographical location (IP location).
# version: 0.1
# url: https://github.com/discourse-org/discourse-geoblocking

enabled_site_setting :geoblocking_enabled

require_relative("lib/geoblocking_middleware")

DiscourseEvent.on(:after_initializers) do
  # Failover and multisite middlewares are added to the stack based on the site's configuration.
  # If either of them exist, we must run the geoblocking middleware after them to avoid
  # unexpected behaviours
  if defined?(RailsFailover::ActiveRecord) && Rails.configuration.active_record_rails_failover
    Rails.configuration.middleware.insert_after(RailsFailover::ActiveRecord::Middleware, GeoblockingMiddleware)
  elsif Rails.configuration.multisite
    Rails.configuration.middleware.insert_after(RailsMultisite::Middleware, GeoblockingMiddleware)
  else
    Rails.configuration.middleware.unshift(GeoblockingMiddleware)
  end
end

after_initialize do
  require_relative("app/controllers/geoblocking_controller")
end
