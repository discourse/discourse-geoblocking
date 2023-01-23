# frozen_string_literal: true

require "rails_helper"

describe DiscourseGeoblocking do
  describe ".allowed_countries" do
    it "is reset when site setting changes" do
      SiteSetting.geoblocking_allowed_countries = "EU"
      expect(DiscourseGeoblocking.allowed_countries).to contain_exactly("EU")

      SiteSetting.geoblocking_allowed_countries = "EU|US"
      expect(DiscourseGeoblocking.allowed_countries).to contain_exactly("EU", "US")
    end
  end

  describe ".allowed_geoname_ids" do
    it "is reset when site setting changes" do
      SiteSetting.geoblocking_allowed_geoname_ids = "1"
      expect(DiscourseGeoblocking.allowed_geoname_ids).to contain_exactly(1)

      SiteSetting.geoblocking_allowed_geoname_ids = "1|2"
      expect(DiscourseGeoblocking.allowed_geoname_ids).to contain_exactly(1, 2)
    end
  end

  describe ".blocked_countries" do
    it "is reset when site setting changes" do
      SiteSetting.geoblocking_blocked_countries = "EU"
      expect(DiscourseGeoblocking.blocked_countries).to contain_exactly("EU")

      SiteSetting.geoblocking_blocked_countries = "EU|US"
      expect(DiscourseGeoblocking.blocked_countries).to contain_exactly("EU", "US")
    end
  end

  describe ".blocked_geoname_ids" do
    it "is reset when site setting changes" do
      SiteSetting.geoblocking_blocked_geoname_ids = "1"
      expect(DiscourseGeoblocking.blocked_geoname_ids).to contain_exactly(1)

      SiteSetting.geoblocking_blocked_geoname_ids = "1|2"
      expect(DiscourseGeoblocking.blocked_geoname_ids).to contain_exactly(1, 2)
    end
  end
end
