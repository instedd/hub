class ConnectorsController < ApplicationController
  def reflect
    connector = Connector.find(params[:id])
    target = connector.lookup(params[:path].to_s.split('/'))
    render json: target.reflect
  end
end
