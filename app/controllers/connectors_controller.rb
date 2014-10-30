class ConnectorsController < ApplicationController
  def reflect
    connector = Connector.find(params[:id])
    target = connector.lookup(params[:path].to_s.split('/'))
    if params[:event]
      target = target.reflect_event(params[:event])
    else
      target = target.reflect
    end
    render json: target
  end
end
