# frozen_string_literal: true
# rubocop:disable RSpec/NamedSubject

require "rails_helper"

describe GeoblockingMiddleware do
  let(:app) { lambda { |env| [200, { "Content-Type" => "text/plain" }, ["OK"]] } }
  let(:gb_ip) { "81.2.69.142" }
  let(:us_ip) { "216.160.83.56" }
  subject { described_class.new(app) } # rubocop:disable Rspec/LeadingSubject

  def make_env(opts = {})
    {
      "HTTP_HOST" => "http://test.com",
      "HTTP_USER_AGENT" =>
        "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36",
      "PATH_INFO" => File.join("/", SecureRandom.alphanumeric),
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" =>
        "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
      "rack.input" => "",
    }.merge(opts)
  end

  before { DiscourseIpInfo.open_db(File.join(Rails.root, "spec", "fixtures", "mmdb")) }

  describe "using countries blocklist" do
    it "uses site settings" do
      SiteSetting.geoblocking_blocked_countries =
        SiteSetting.geoblocking_blocked_countries.split("|").reject { |x| x == "GB" }.join("|")

      env = make_env("REMOTE_ADDR" => gb_ip)

      status, _ = subject.call(env)
      expect(status).to eq(200)
    end

    it "checks for exact match" do
      SiteSetting.geoblocking_blocked_countries = "US-TEST"

      env = make_env("REMOTE_ADDR" => us_ip)

      status, _ = subject.call(env)
      expect(status).to eq(200)
    end

    it "does not block US IP by default" do
      env = make_env("REMOTE_ADDR" => us_ip)

      status, _ = subject.call(env)
      expect(status).to eq(200)
    end

    it "does not block UK IP by default" do
      env = make_env("REMOTE_ADDR" => gb_ip)

      status, _ = subject.call(env)
      expect(status).to eq(200)
    end

    it "blocks ip present in blocklist" do
      SiteSetting.geoblocking_blocked_countries = "GB"
      env = make_env("REMOTE_ADDR" => gb_ip)

      status, _ = subject.call(env)
      expect(status).to eq(403)
    end

    it "blocks ip even if geoname ids are missing" do
      info = DiscourseIpInfo.get(gb_ip)
      info[:geoname_ids] = []
      DiscourseIpInfo.stubs(:get).with(gb_ip).returns(info)

      SiteSetting.geoblocking_blocked_countries = "GB"
      env = make_env("REMOTE_ADDR" => gb_ip)

      status, _ = subject.call(env)
      expect(status).to eq(403)
    end

    it "does not block allowed static resources" do
      SiteSetting.geoblocking_blocked_countries = "GB"

      env = make_env("REMOTE_ADDR" => gb_ip)

      status, _ = subject.call(env)
      expect(status).to eq(403)

      %w[assets images uploads stylesheets service-worker].each do |path|
        env =
          make_env(
            "PATH_INFO" => File.join("/", path, SecureRandom.alphanumeric),
            "REMOTE_ADDR" => gb_ip,
          )

        status, _ = subject.call(env)
        expect(status).to eq(200)
      end
    end

    it "does not block ip if geoname ids are missing" do
      info = DiscourseIpInfo.get(gb_ip)
      info[:geoname_ids] = []
      DiscourseIpInfo.stubs(:get).with(gb_ip).returns(info)

      SiteSetting.geoblocking_blocked_countries = "US"
      env = make_env("REMOTE_ADDR" => gb_ip)

      status, _ = subject.call(env)
      expect(status).to eq(200)
    end

    it "allows specific paths through the geoblocking_allowed_paths site setting" do
      SiteSetting.geoblocking_blocked_countries = "GB"
      SiteSetting.geoblocking_allowed_paths = "tos"
      env = make_env("REMOTE_ADDR" => gb_ip, "PATH_INFO" => "/tos")

      status, _ = subject.call(env)
      expect(status).to eq(200)
    end
  end

  describe "using countries allowlist" do
    describe "with populated allowlist" do
      before { SiteSetting.geoblocking_allowed_countries = "CA|GB" }

      it "does not block allowlisted ips" do
        env = make_env("REMOTE_ADDR" => gb_ip)

        status, _ = subject.call(env)
        expect(status).to eq(200)
      end

      it "blocks ip not present in allowlist" do
        env = make_env("REMOTE_ADDR" => us_ip)

        status, _ = subject.call(env)
        expect(status).to eq(403)
      end

      %w[
        srv/status
        u/admin-login
        users/admin-login
        session/email-login
        session/csrf
        logs/report_js_error
        manifest.webmanifest
      ].each do |path|
        it "never blocks '#{path}'" do
          env = make_env("REMOTE_ADDR" => us_ip, "PATH_INFO" => File.join("/", path))

          status, _ = subject.call(env)
          expect(status).to eq(200)
        end
      end

      it "never blocks admin users" do
        SiteSetting.geoblocking_enabled = false
        admin = Fabricate(:admin)
        sign_in(admin)
        token = UserAuthToken.generate!(user_id: admin.id)
        SiteSetting.geoblocking_enabled = true

        env =
          make_env(
            "REMOTE_ADDR" => us_ip,
            "PATH_INFO" => "/",
            "HTTP_COOKIE" => "_t=#{token.unhashed_auth_token}",
          )
        status, _ = subject.call(env)
        expect(status).to eq(200)
      end

      it "blocks regular users" do
        SiteSetting.geoblocking_enabled = false
        user = Fabricate(:user)
        sign_in(user)
        token = UserAuthToken.generate!(user_id: user.id)
        SiteSetting.geoblocking_enabled = true

        env =
          make_env(
            "REMOTE_ADDR" => us_ip,
            "PATH_INFO" => "/",
            "HTTP_COOKIE" => "_t=#{token.unhashed_auth_token}",
          )
        status, _ = subject.call(env)
        expect(status).to eq(403)
      end

      describe "with blocked_redirect" do
        before { SiteSetting.geoblocking_blocked_redirect = "http://markvanlan.com" }

        it "redirects on blocked request" do
          env = make_env("REMOTE_ADDR" => us_ip)

          response = subject.call(env)
          expect(response.first).to eq(302)
          expect(response.second["Location"]).to eq(SiteSetting.geoblocking_blocked_redirect)
        end
      end
    end

    describe "with unpopulated allowlist" do
      before { SiteSetting.geoblocking_allowed_countries = "" }

      it "does not block any ips" do
        env = make_env("REMOTE_ADDR" => us_ip)
        status, _ = subject.call(env)
        expect(status).to eq(200)

        env = make_env("REMOTE_ADDR" => gb_ip)
        status, _ = subject.call(env)
        expect(status).to eq(200)
      end
    end
  end

  describe "using geoname IDs blacklist" do
    it "blocks" do
      SiteSetting.geoblocking_blocked_geoname_ids = "2643743" # London, GB

      env = make_env("REMOTE_ADDR" => us_ip)
      status, _ = subject.call(env)
      expect(status).to eq(200)

      env = make_env("REMOTE_ADDR" => gb_ip)
      status, _ = subject.call(env)
      expect(status).to eq(403)
    end
  end

  describe "using geoname IDs allowlist" do
    it "blocks" do
      SiteSetting.geoblocking_allowed_geoname_ids = "2643743" # London, GB

      env = make_env("REMOTE_ADDR" => us_ip)
      status, _ = subject.call(env)
      expect(status).to eq(403)

      env = make_env("REMOTE_ADDR" => gb_ip)
      status, _ = subject.call(env)
      expect(status).to eq(200)
    end
  end

  describe "using an invalid API key" do
    it "treats invalid API key requests as non-admin requests" do
      user = Fabricate(:user)
      api_key = ApiKey.create!(user: user, revoked_at: Time.zone.now, last_used_at: nil)

      env =
        make_env(
          {
            "HTTP_API_USERNAME" => user.username.downcase,
            "HTTP_API_KEY" => api_key.key,
            "REMOTE_ADDR" => us_ip,
            "REQUEST_URI" => "/",
          },
        )

      status, _ = subject.call(env)
      expect(status).to eq(200)
    end
  end
end
