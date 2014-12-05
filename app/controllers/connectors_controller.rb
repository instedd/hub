class ConnectorsController < ApplicationController
  add_breadcrumb 'Connectors', :connectors_path
  protect_from_forgery except: :invoke

  # connectors can be edited. accessible_connectors are just listed
  expose(:accessible_connectors) { Connector.with_optional_user(current_user) }
  expose(:connectors) { current_user.connectors }
  expose(:connector) do
    if params[:id]
      connectors.find params[:id]
    else
      connector = (params[:type] || params[:connector][:type]).constantize.new
      connector.user_id = current_user.id
      connector
    end
  end

  def index
  end

  def new
    add_breadcrumb 'New connector'
  end

  def edit
    if connector.has_notifiable_events? && !connector.secret_token
      @secret_token = connector.generate_secret_token!
    end

    add_breadcrumb connector.name
  end

  def create
    if connector.needs_authorization?
      state = params.require(:connector).permit!.to_json
      redirect_to connector.authorization_uri(url_for(controller: 'connectors', action: connector.callback_action), state)
    else
      connector.update_attributes params.require(:connector).permit!
      if connector.save
        redirect_to connectors_path, notice: "Connector #{connector.name} successfully created."
      else
        render action: "new"
      end
    end
  end

  def update
    connector.update_attributes params.require(:connector).permit!
    if connector.save
      redirect_to connectors_path, notice: "Connector #{connector.name} successfully updated."
    else
      render action: "edit"
    end
  end

  def destroy
    connector.destroy
    redirect_to connectors_path, notice: "Connector #{connector.name} successfully deleted."
  end

  def google_fusiontables_callback
    params[:type] = "GoogleFusionTablesConnector"
    connector = self.connector

    api = GoogleFusionTablesConnector.api_client
    api.authorization.code = params[:code]
    api.authorization.redirect_uri = url_for(controller: 'connectors', action: connector.callback_action)
    access_token = api.authorization.fetch_access_token!

    connector.update_attributes JSON.parse(params[:state])
    connector.access_token = access_token["access_token"]
    connector.refresh_token = access_token["refresh_token"]
    connector.expires_at = access_token["expires_in"].seconds.from_now

    if connector.save
      redirect_to edit_connector_path(connector), notice: "Connector #{connector.name} successfully created."
    else
      render action: "new"
    end

  end


  def google_spreadsheets_callback
    # These two lines so we can reuse decent_exposure's logic
    params[:type] = "GoogleSpreadsheetsConnector"
    connector = self.connector

    api = GoogleSpreadsheetsConnector.api_client
    api.authorization.code = params[:code]
    api.authorization.redirect_uri = url_for(controller: 'connectors', action: connector.callback_action)
    access_token = api.authorization.fetch_access_token!

    connector.update_attributes JSON.parse(params[:state])
    connector.access_token = access_token["access_token"]
    connector.refresh_token = access_token["refresh_token"]
    connector.expires_at = access_token["expires_in"].seconds.from_now

    if connector.save
      redirect_to edit_connector_path(connector), notice: "Connector #{connector.name} successfully created."
    else
      render action: "new"
    end
  end

  def authorization_callback
    params[:type] = session[:connector_class_name]
    connector = self.connector

    connector.update_attributes session[:connector_params]

    session.delete :connector_class_name
    session.delete :connector_params

    connector.finish_authorization(params, authorization_callback_connectors_url)
    if connector.save
      redirect_to connectors_path, notice: "Connector #{connector.name} successfully created."
    else
      render action: "new"
    end
  end

  def invoke
    connector = connector_from_guid()
    target = connector.lookup_path(params[:path], current_user)
    response = target.invoke(JSON.parse(request.body.read), current_user)
    render json: response
  end

  def poll
    connector = connector_from_guid()
    Connector::PollJob.perform(connector.id)
    redirect_to connectors_path, notice: "Connector #{connector.name} successfully polled."
  end

  private

  def connector_from_guid
    accessible_connectors.find_by_guid(params[:id])
  end
end
