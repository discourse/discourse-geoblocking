# frozen_string_literal: true

# name: discourse-geoblocking
# about: Restricts access to content based upon the user's geographical location (IP location).
# version: 0.1
# url: https://github.com/discourse-org/discourse-geoblocking

enabled_site_setting :geoblocking_enabled

require_relative("lib/geoblocking_middleware")
if Rails.env == 'development' && !ENV['TRACK_REQUESTS']
  Rails.configuration.middleware.unshift(GeoblockingMiddleware)
else
  DiscourseEvent.on(:request_tracker_registered) do
    Rails.configuration.middleware.unshift(GeoblockingMiddleware)
  end
end

after_initialize do
  require_relative("app/controllers/geoblocking_controller")
end
