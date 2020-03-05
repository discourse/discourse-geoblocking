# frozen_string_literal: true

require 'rails_helper'

describe ApplicationController do
  let(:gb_ip) { "81.2.69.142" }
  let(:us_ip) { "216.160.83.56" }

  before do
    DiscourseIpInfo.open_db(File.join(Rails.root, 'spec', 'fixtures', 'mmdb'))
  end

  describe "geoblocking enabled" do
    before do
      SiteSetting.geoblocking_enabled = true
    end

    describe "using blacklist (use_whitelist disabled)" do
      before do
        SiteSetting.geoblocking_use_whitelist = false
      end

      it 'uses site settings' do
        SiteSetting.geoblocking_countries = SiteSetting.geoblocking_countries.split('|').reject { |x| x == "GB" }.join('|')
        ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(gb_ip)
        get "/"
        expect(status).to eq(200)
      end

      it 'does not block non-European IP by default' do
        ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(us_ip)
        get "/"
        expect(status).to eq(200)
      end

      it 'blocks European IPs by default' do
        ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(gb_ip)
        get "/"
        expect(status).to eq(403)
      end

      it 'does not block static resources' do
        ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(gb_ip)
        get "/stylesheets/mobile.css"
        expect(status).to eq(200)
      end
    end

    describe "always-open routes" do
      before do
        SiteSetting.geoblocking_whitelist = "GB"
      end

      it 'never blocks srv/status route' do
        ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(us_ip)
        get "/srv/status"

        expect(response.status).to eq(200)
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
          ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(gb_ip)
          get '/'

          expect(response.status).to eq(200)
        end

        it 'blocks ip not present in whitelist' do
          ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(us_ip)
          get '/'

          expect(response.status).to eq(403)
        end

        describe "with blocked_redirect" do
          before do
            SiteSetting.geoblocking_blocked_redirect = "http://markvanlan.com"
          end

          it 'redirects on blocked request' do
            ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(us_ip)
            get '/'

            expect(response.status).to eq(302)
            expect(response.location).to eq(SiteSetting.geoblocking_blocked_redirect)
          end
        end
      end

      describe "with unpopulated whitelist" do
        before do
          SiteSetting.geoblocking_whitelist = ""
        end

        it 'does not block any ips' do
          [us_ip, gb_ip].each do |ip|
            ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(ip)
            get '/'

            expect(response.status).to eq(200)
          end
        end
      end

      describe "always-open routes" do
        before do
          SiteSetting.geoblocking_whitelist = "GB"
        end

        it 'never blocks srv/status route' do
          sign_in(Fabricate(:user))
          ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(us_ip)
          get "/srv/status"

          expect(response.status).to eq(200)
        end
      end
    end
  end

  describe "geoblocking disabled" do

  end
end
