class ApiController < ApplicationController
  after_action :allow_iframe, only: :picker
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  before_action :verify_access_token!, only: :notify
  before_filter :authenticate_api_user!, except: :notify

  expose(:accessible_connectors) { Connector.with_optional_user(current_user) }
  expose(:connector) { accessible_connectors.find_by_guid(params[:id]) }
  expose(:target) { connector.lookup_path(params[:path], current_user) }

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
    render json: target.reflect(request_context)
  end

  def query
    options = {page: 1, page_size: 20}.merge(params.slice(:page, :page_size))

    if target.is_a? Entity
      render json: target.raw(request_context)
    else
      items = target.query(entity_filter, request_context, options)
      render json: items.map { |e| e.raw(request_context) }
    end
  end

  def insert
    target.insert(params[:properties], request_context)
    render nothing: true, status: 200
  end

  def update
    properties = params[:properties]
    updated_entity_count = target.update(entity_filter, properties, request_context)

    if updated_entity_count == 0 && params[:create_or_update]
      target.insert(properties, request_context)
    end

    render nothing: true, status: 200
  end

  def delete
    target.delete(entity_filter, request_context)
    render nothing: true, status: 200
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

  def entity_filter
    params[:filter] = nil if params[:filter] == ""
    (params[:filter] || {}).slice(*target.filters(current_user))
  end

  def verify_access_token!
    unless connector.authenticate_with_secret_token(request.headers["X-InSTEDD-Hub-Token"])
      render json: {message: "Invalid authentication token"}, status: :unauthorized
    end
  end

  def allow_iframe
    response.headers.except! 'X-Frame-Options'
  end
end
