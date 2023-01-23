# frozen_string_literal: true

require "rails_helper"

describe GeoblockingController do
  before { SiteSetting.geoblocking_enabled = true }

  it "does not redirect users in a loop if login_required" do
    SiteSetting.login_required = true
    SiteSetting.geoblocking_allowed_countries = "EU"

    get Discourse.base_url
    expect(response.status).to eq(403)
    expect(response.body).to include("Access forbidden based on location.")
  end

  describe "RSS feed and login_required" do
    before do
      SiteSetting.login_required = true
      DiscourseIpInfo.open_db(File.join(Rails.root, "spec", "fixtures", "mmdb"))
    end

    let(:us_ip) { "216.160.83.56" }
    let(:user) { Fabricate(:user) }
    let(:api_key) { ApiKey.create!(user_id: user.id, created_by_id: Discourse.system_user) }
    let(:rss_path) { "/latest.rss?api_key=#{api_key.key}&api_username=#{user.username_lower}" }
    let(:json_path) { "/latest.json?api_key=#{api_key.key}&api_username=#{user.username_lower}" }

    it "allows access if not blocked country" do
      SiteSetting.geoblocking_blocked_countries = "EU"

      get rss_path, env: { REMOTE_ADDR: us_ip }
      expect(response.status).to eq(200)

      # Confirm it's still not allowed for json
      get json_path, env: { REMOTE_ADDR: us_ip }
      expect(response.status).to eq(403)
    end

    it "prevents access if blocked country" do
      SiteSetting.geoblocking_blocked_countries = "US"

      get rss_path, env: { REMOTE_ADDR: us_ip }
      expect(response.status).to eq(403)

      get json_path, env: { REMOTE_ADDR: us_ip }
      expect(response.status).to eq(403)
    end
  end
end
