# frozen_string_literal: true

class RenameSiteSettingsToAllowlist < ActiveRecord::Migration[6.1]
  def up
    execute "UPDATE site_settings SET name = 'geoblocking_allowed_countries' WHERE name = 'geoblocking_whitelist'"
    execute "UPDATE site_settings SET name = 'geoblocking_blocked_countries' WHERE name = 'geoblocking_countries'"
  end

  def down
    execute "UPDATE site_settings SET name = 'geoblocking_whitelist' WHERE name = 'geoblocking_allowed_countries'"
    execute "UPDATE site_settings SET name = 'geoblocking_countries' WHERE name = 'geoblocking_blocked_countries'"
  end
end
