class Api::EventHandlersController < ApplicationController

  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  before_filter :authenticate_api_user!

  expose(:event_handlers) { current_user.event_handlers }
  expose(:event_handler)

  def index
    # render json: event_handlers
    # respond_to :json
  end

  def create
    connectors = Connector.with_optional_user(current_user)

    event = connectors.find_by_guid(params[:event_handler][:event][:connector]).lookup_path(params[:event_handler][:event][:path], request_context)
    action = connectors.find_by_guid(params[:event_handler][:action][:connector]).lookup_path(params[:event_handler][:action][:path], request_context)

    event_handler = event.subscribe(action, params[:event_handler][:binding], request_context)
    event_handler.name = params[:event_handler][:name]
    event_handler.enabled = params[:event_handler][:enabled]

    if event_handler.save
      render json: {success: true}
    else
      render json: {success: false, errors: event_handler.errors.messages}
    end
  end

  def destroy
    event_handler.destroy
    render json: {success: true}
  end

end
