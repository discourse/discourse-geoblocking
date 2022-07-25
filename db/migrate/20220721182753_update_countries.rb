# frozen_string_literal: true

class UpdateCountries < ActiveRecord::Migration[6.1]
  REMOVED_CODES = ["A1", "A2", "AP", "EU", "CS", "FX", "O1"]

  def up
    SiteSetting.geoblocking_allowed_countries = remove_countries(SiteSetting.geoblocking_allowed_countries)
    SiteSetting.geoblocking_blocked_countries = remove_countries(SiteSetting.geoblocking_blocked_countries)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def remove_countries(value)
    value.split("|")
      .reject { |code| REMOVED_CODES.include?(code) }
      .join("|")
  end
end
