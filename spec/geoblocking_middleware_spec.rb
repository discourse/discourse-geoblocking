# frozen_string_literal: true

require 'rails_helper'

describe GeoblockingMiddleware do

  let(:app) { lambda { |env| [200, { 'Content-Type' => 'text/plain' }, ['OK']] } }
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

  it 'uses site settings' do
    SiteSetting.geoblocking_countries = SiteSetting.geoblocking_countries.split('|').reject { |x| x == "GB" }.join('|')

    env = make_env("REMOTE_ADDR" => "81.2.69.142")

    status, _ = subject.call(env)
    expect(status).to eq(200)
  end

  it 'does not block non-European IP by default' do
    env = make_env("REMOTE_ADDR" => "216.160.83.56")

    status, _ = subject.call(env)
    expect(status).to eq(200)
  end

  it 'blocks European IPs by default' do
    env = make_env("REMOTE_ADDR" => "81.2.69.142")

    status, _ = subject.call(env)
    expect(status).to eq(403)
  end

  it 'does not block static resources' do
    env = make_env(
      "REQUEST_PATH" => "/stylesheets/hello.css",
      "REMOTE_ADDR" => "81.2.69.142"
    )

    status, _ = subject.call(env)
    expect(status).to eq(200)
  end

end
