class ConnectorsController < ApplicationController
  def reflect
    connector = Connector.find(params[:id])
    target = connector.lookup(params[:path].to_s.split('/'))
    reflect_url_proc = ->(path) { reflect_with_path_connector_url(params[:id], path) }
    render json: target.reflect(reflect_url_proc)
  end
end
