class ApiController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  before_filter :authenticate_api_user!

  expose(:accessible_connectors) { Connector.with_optional_user(current_user) }

  def connectors
    c = accessible_connectors.map do |c|
      {
        label: c.name,
        guid: c.guid,
        reflect_url: reflect_api_url(c.guid),
      }
    end
    render json: c
  end

  def reflect
    connector = connector_from_guid()
    target = connector.lookup_path(params[:path], current_user)
    reflect_url_proc = ->(path) { path.blank? ? reflect_api_url(params[:id]) : reflect_with_path_api_url(params[:id], path) }
    render json: target.reflect(reflect_url_proc, current_user)
  end

  def data
    target = connector_from_guid.lookup_path(params[:path], current_user)
    options = {page: 1, page_size: 20}.merge(params.slice(:page, :page_size))
    data_url_proc = ->(path) { data_with_path_api_url(params[:id], path) }

    if target.is_a? Entity
      render json: target.raw(data_url_proc, current_user)
    else
      case request.method
      when "GET"
        filters = (params[:filter] || {}).slice(*target.filters)
        items = target.query(filters, current_user, options)
        render json: items.map { |e| e.raw(data_url_proc, current_user) }
      else
        head :not_found
      end
    end
  end

  private

  def connector_from_guid
    accessible_connectors.find_by_guid(params[:id])
  end

end
