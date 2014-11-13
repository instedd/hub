class CallbacksController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :verify_access_token!
  protect_from_forgery except: :enqueue

  expose(:connector) do
    if params[:connector]
      Connector.where(type: "#{params[:connector]}_connector".classify).shared.first
    end
  end

  def enqueue
    raw_post = request.raw_post.empty? ? "{}" : request.raw_post
    task_id = connector.enqueue_event(params[:event], raw_post)
    render json: {id: task_id}, status: :ok
  end

  def verify_access_token!
    if !params[:token] || params[:token] != Settings.authentication_token
      render json: {message: "Invalid authentication token"}, status: :unauthorized
    end
   end
end
