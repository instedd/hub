class ApiController < ApplicationController
  after_action :allow_iframe, only: :picker
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  before_action :verify_access_token!, only: :notify
  before_filter :authenticate_api_user!, except: :notify

  expose(:accessible_connectors) { Connector.with_optional_user(current_user) }
  expose(:connector) { accessible_connectors.find_by_guid(params[:id]) }

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
    target = connector.lookup_path(params[:path], current_user)
    reflect_url_proc = ->(path) { path.blank? ? reflect_api_url(params[:id]) : reflect_with_path_api_url(params[:id], path) }
    render json: target.reflect(reflect_url_proc, current_user)
  end

  def data
    target = connector.lookup_path(params[:path], current_user)
    options = {page: 1, page_size: 20}.merge(params.slice(:page, :page_size))
    data_url_proc = ->(path) { data_with_path_api_url(params[:id], path) }

    if target.is_a? Entity
      render json: target.raw(data_url_proc, current_user)
    else
      case request.method
      when "GET"
        params[:filter] = nil if params[:filter] == ""
        filters = (params[:filter] || {})
        items = target.query(filters, current_user, options)
        render json: items.map { |e| e.raw(data_url_proc, current_user) }
      else
        head :not_found
      end
    end
  end

  def picker
    render layout: false
  end

  def notify
    raw_post = request.raw_post || "{}"

    # This will raise an exception if the json is invalid
    JSON.parse raw_post

    Resque.enqueue_to(:hub, Connector::NotifyJob, connector.id, params[:path], raw_post)

    render json: {}, status: :ok
  end

  private

  def verify_access_token!
    unless connector.authenticate_with_secret_token(request.headers["X-InSTEDD-Hub-Token"])
      render json: {message: "Invalid authentication token"}, status: :unauthorized
    end
  end

  def allow_iframe
    response.headers.except! 'X-Frame-Options'
  end
end
