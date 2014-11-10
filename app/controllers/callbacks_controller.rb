class CallbacksController < ApplicationController

  expose(:connector) do
    if params[:connector]
      Connector.where(type: "#{params[:connector]}_connector".classify).where("settings -> 'shared' = 'true'").first
    end
  end

  def execute
  end
end
