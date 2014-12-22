class ApiController < ApplicationController
  after_action :allow_iframe, only: :picker
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  before_filter :authenticate_api_user!, except: :notify

  expose(:accessible_connectors) { Connector.with_optional_user(current_user) }
  expose(:connector) { accessible_connectors.find_by_guid(params[:id]) }
  expose(:target) { connector.lookup_path(params[:path], request_context) }

  def connectors
    c = accessible_connectors.map do |c|
      {
        label: c.name,
        guid: c.guid,
        reflect_url: api_reflect_url(c.guid),
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
      res = items.map do |e|
        e.is_a?(Hash) ? e : e.raw(request_context)
      end
      render json: res
    end
  end

  def insert
    properties = params[:properties]
    remove_nil_hash_values_from(properties)
    target.insert(properties, request_context)
    render nothing: true, status: 200
  end

  def update
    properties = params[:properties]
    remove_nil_hash_values_from(properties)
    updated_entity_count = target.update(entity_filter, properties, request_context)
    if updated_entity_count == 0 && params[:create_or_update] == 'true'
      target.insert(properties, request_context)
    end

    render nothing: true, status: 200
  end

  def delete
    target.delete(entity_filter, request_context)
    render nothing: true, status: 200
  end

  def picker
    @type = params[:type] # 'entity_set' | 'action' | 'event'
    render layout: false
  end

  def notify
    notified_connector = Connector.find_by_guid params[:id]
    if !notified_connector.authenticate_with_secret_token(request.headers["X-InSTEDD-Hub-Token"])
      render json: {message: "Invalid authentication token"}, status: :unauthorized
    else
      raw_post = request.raw_post || "{}"

      # This will raise an exception if the json is invalid
      JSON.parse raw_post

      Resque.enqueue_to(:hub, Connector::NotifyJob, notified_connector.id, params[:path], raw_post)

      render json: {}, status: :ok
    end
  end

  def invoke
    target = connector.lookup_path(params[:path], request_context)
    args = JSON.parse(request.body.read)
    remove_nil_hash_values_from(args)
    response = target.invoke(args, request_context)
    render json: response
  end

  private

  def entity_filter
    params[:filter] = nil if params[:filter] == ""
    filters = (params[:filter] || {}).slice(*target.filters(request_context))
    remove_nil_hash_values_from filters

    filters
  end

  def allow_iframe
    response.headers.except! 'X-Frame-Options'
  end

  def remove_nil_hash_values_from(args)
    case args
    when Array
      args.each { |arg| remove_nil_hash_values_from arg }
    when Hash
      args.delete_if do |key, value|
        if value.nil? || (value.is_a?(String) && value.empty?)
          true
        else
          remove_nil_hash_values_from value
          false
        end
      end
    end
  end
end
