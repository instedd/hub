class RequestContext
  def initialize(user, controller = nil)
    @user = user
    @controller = controller
  end

  def data_url(path)
    if path.blank?
      @controller.data_api_url(connector_id)
    else
      @controller.data_with_path_api_url(connector_id, path)
    end
  end

  def reflect_url(path)
    if path.blank?
      @controller.reflect_api_url(connector_id)
    else
      @controller.reflect_with_path_api_url(connector_id, path)
    end
  end

  def user
    @user
  end

  def connector_id
    @controller.params[:id]
  end
end
