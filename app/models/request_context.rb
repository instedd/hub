class RequestContext
  def initialize(user, controller = nil)
    @user = user
    @controller = controller
  end

  def data_url(path)
    @controller.api_data_url(connector_id, path)
  end

  def reflect_url(path)
    @controller.api_reflect_url(connector_id, path)
  end

  def user
    @user
  end

  def connector_id
    @controller.params[:id]
  end
end
