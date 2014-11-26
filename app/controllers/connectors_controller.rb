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
    respond_to do |format|
      format.html
      format.json do
        c = accessible_connectors.map do |c|
          {
            label: c.name,
            guid: c.guid,
            reflect_url: reflect_connector_url(c.guid),
          }
        end
        render json: c
      end
    end
  end

  def new
    add_breadcrumb 'New connector'
  end

  def edit
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

  def reflect
    connector = connector_from_guid()
    target = connector.lookup_path(params[:path], current_user)
    reflect_url_proc = ->(path) { path.blank? ? reflect_connector_url(params[:id]) : reflect_with_path_connector_url(params[:id], path) }
    render json: target.reflect(reflect_url_proc, current_user)
  end

  def data
    target = connector_from_guid.lookup_path(params[:path], current_user)
    options = {page: 1, page_size: 20}.merge(params.slice(:page, :page_size))
    data_url_proc = ->(path) { data_with_path_connector_url(params[:id], path) }

    if target.is_a? Entity
      render json: target.raw(data_url_proc, current_user)
    else
      case request.method
      when "GET"
        if target.protocols.include? :select
          render json: target.select(params[:filter] || {}, current_user, options).map { |e| e.raw(data_url_proc, current_user) }
        else
          render json: target.entities(current_user).map { |e| e.raw(data_url_proc, current_user) }
        end
      else
        head :not_found
      end
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
