class ConnectorsController < ApplicationController
  def reflect
    connector = Connector.find(params[:id])
    target = connector.lookup_path(params[:path])
    reflect_url_proc = ->(path) { reflect_with_path_connector_url(params[:id], path) }
    render json: target.reflect(reflect_url_proc)
  end

  def query
    connector = Connector.find(params[:id])
    target = connector.lookup_path(params[:path])
    query_url_proc = ->(path) { query_with_path_connector_url(params[:id], path) }
    render json: target.query(query_url_proc)
  end
end
