# frozen_string_literal: true

class GeoblockingController < ApplicationController
  skip_before_action :check_xhr, :preload_json

  def blocked
    respond_to do |format|
      format.html do
        append_view_path(File.expand_path("../../views", __FILE__))
        render :blocked, layout: 'no_ember', status: :forbidden
      end
      format.json do
        render json: { errors: [I18n.t('geoblocking.blocked')] }
      end
      format.all do
        head :forbidden
      end
    end
  end
end
