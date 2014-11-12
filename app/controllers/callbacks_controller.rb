class CallbacksController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :verify_access_token!

  expose(:connector) do
    if params[:connector]
      Connector.where(type: "#{params[:connector]}_connector".classify).shared.first
    end
  end

  def execute
    render json: {}, status: :ok
  end

  def verify_access_token!
    if !params[:token] || params[:token] != Settings.authentication_token
      render json: {message: "Invalid authentication token"}, status: :unauthorized
    end
   end
end
