class ConnectorsController < ApplicationController
  add_breadcrumb 'Connectors', :connectors_path
  protect_from_forgery except: :invoke

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
        c = connectors.map do |c|
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
    connector.update_attributes params.require(:connector).permit!
    if connector.save
      redirect_to connectors_path, notice: "Connector #{connector.name} successfully created."
    else
      render action: "new"
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

  def reflect
    connector = connector_from_guid()
    target = connector.lookup_path(params[:path])
    reflect_url_proc = ->(path) { reflect_with_path_connector_url(params[:id], path) }
    render json: target.reflect(reflect_url_proc, current_user)
  end

  def query
    connector = connector_from_guid()
    target = connector.lookup_path(params[:path])
    query_url_proc = ->(path) { query_with_path_connector_url(params[:id], path) }
    render json: target.query(query_url_proc)
  end

  def invoke
    connector = connector_from_guid()
    target = connector.lookup_path(params[:path])
    response = target.invoke(JSON.parse(request.body.read))
    render json: response
  end

  def browse
  end

  private

  def connector_from_guid
    Connector.with_optional_user(current_user).find_by_guid(params[:id])
  end
end
