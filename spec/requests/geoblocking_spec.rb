# frozen_string_literal: true

require 'rails_helper'

describe GeoblockingController do
  it 'does not redirect users in a loop if login_required' do
    SiteSetting.login_required = true
    SiteSetting.geoblocking_use_whitelist = true
    SiteSetting.geoblocking_whitelist = 'EU'

    get Discourse.base_url
    expect(response.status).to eq(403)
    expect(response.body).to include('Access forbidden based on location.')
  end
end
