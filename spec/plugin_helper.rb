# frozen_string_literal: true

RSpec.configure do |config|
  # Site setting overrides are rolled back between examples by resetting the
  # settings provider, which does not trigger `site_setting_changed`. Without
  # this hook the plugin cache is never invalidated and the countries/geoname
  # IDs of one example leak into the next one.
  #
  # `after_commit: false` is required because this hook runs before the specs'
  # transaction bookkeeping is set up, so a deferred clear would be registered
  # against the example's transaction and lost when it is rolled back.
  config.before { DiscourseGeoblocking.cache.clear(after_commit: false) }
end
