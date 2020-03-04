# frozen_string_literal: true

require 'rails_helper'

describe GeoblockingMiddleware do

  let(:app) { lambda { |env| [200, { 'Content-Type' => 'text/plain' }, ['OK']] } }
  let(:gb_ip) { "81.2.69.142" }
  let(:us_ip) { "216.160.83.56" }
  subject { described_class.new(app) }

  def make_env(opts = {})
    {
      "HTTP_HOST" => "http://test.com",
      "HTTP_USER_AGENT" => "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36",
      "REQUEST_URI" => "/path?bla=1",
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
      "rack.input" => ""
    }.merge(opts)
  end

  before do
    DiscourseIpInfo.open_db(File.join(Rails.root, 'spec', 'fixtures', 'mmdb'))
  end

  describe "using blacklist (use_whitelist disabled)" do
    before do
      SiteSetting.geoblocking_use_whitelist = false
    end

    it 'uses site settings' do
      SiteSetting.geoblocking_countries = SiteSetting.geoblocking_countries.split('|').reject { |x| x == "GB" }.join('|')

      env = make_env("REMOTE_ADDR" => gb_ip)

      status, _ = subject.call(env)
      expect(status).to eq(200)
    end

    it 'does not block non-European IP by default' do
      env = make_env("REMOTE_ADDR" => us_ip)

      status, _ = subject.call(env)
      expect(status).to eq(200)
    end

    it 'blocks European IPs by default' do
      env = make_env("REMOTE_ADDR" => gb_ip)

      status, _ = subject.call(env)
      expect(status).to eq(403)
    end

    it 'does not block static resources' do
      env = make_env(
        "REQUEST_PATH" => "/stylesheets/hello.css",
        "REMOTE_ADDR" => gb_ip
      )

      status, _ = subject.call(env)
      expect(status).to eq(200)
    end
  end

  describe "use_whitelist enabled" do
    before do
      SiteSetting.geoblocking_use_whitelist = true
    end

    describe "with populated whitelist" do
      before do
        SiteSetting.geoblocking_whitelist = "CA|GB"
      end

      it 'does not block whitelisted ips' do
        env = make_env("REMOTE_ADDR" => gb_ip)

        status, _ = subject.call(env)
        expect(status).to eq(200)
      end

      it 'blocks ip not present in whitelist' do
        env = make_env("REMOTE_ADDR" => us_ip)

        status, _ = subject.call(env)
        expect(status).to eq(403)
      end

      describe "with blocked_redirect" do
        before do
          SiteSetting.geoblocking_blocked_redirect = "http://markvanlan.com"
        end

        it 'redirects on blocked request' do
          env = make_env("REMOTE_ADDR" => us_ip)

          response = subject.call(env)
          expect(response.first).to eq(302)
          expect(response.second["Location"]).to eq(SiteSetting.geoblocking_blocked_redirect)
        end
      end
    end

    describe "with unpopulated whitelist" do
      before do
        SiteSetting.geoblocking_whitelist = ""
      end

      it 'does not block any ips' do
        [us_ip, gb_ip].each do |ip|
          env = make_env("REMOTE_ADDR" => ip)
          status, _ = subject.call(env)
          expect(status).to eq(200)
        end
      end
    end

    describe "always-open routes" do
      before do
        SiteSetting.geoblocking_whitelist = "GB"
      end

      it 'never blocks srv/status route' do
        env = make_env("REMOTE_ADDR" => us_ip, "REQUEST_URI" => "/srv/status")
        status, _ = subject.call(env)
        expect(status).to eq(200)
      end
    end
  end
end
