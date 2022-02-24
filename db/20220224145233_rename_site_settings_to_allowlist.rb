# frozen_string_literal: true

class RenameSiteSettingsToAllowlist < ActiveRecord::Migration[6.1]
  def up
    execute "UPDATE site_settings SET name = 'geoblocking_use_allowlist' WHERE name = 'geoblocking_use_whitelist'"
    execute "UPDATE site_settings SET name = 'geoblocking_allowlist' WHERE name = 'geoblocking_whitelist'"
  end

  def down
    execute "UPDATE site_settings SET name = 'geoblocking_use_whitelist' WHERE name = 'geoblocking_use_allowlist'"
    execute "UPDATE site_settings SET name = 'geoblocking_whitelist' WHERE name = 'geoblocking_allowlist'"
  end
end
