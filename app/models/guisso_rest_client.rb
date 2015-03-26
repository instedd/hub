class GuissoRestClient
  def initialize(connector, user)
    @connector = connector
    @user = user
  end

  def get(url)
    JSON.parse(if use_guisso?
      response = guisso_resource.get(url)
      if response.ok?
        response.body
      else
        raise HttpError.new response
      end
    else
      rest_client_resource(url).get()
    end)
  end

  def post(url, body="")
    if use_guisso?
      response = guisso_resource.post(url, body)
      if response.ok?
        response.body
      else
        raise HttpError.new response
      end
    else
      rest_client_resource(url).post(body) { |response, request, result| handle_request response, request, result }
    end
  end

  def put(url, body="")
    if use_guisso?
      response = guisso_resource.put(url, body)
      if response.ok?
        response.body
      else
        raise HttpError.new response
      end
    else
      rest_client_resource(url).put(body) { |response, request, result| handle_request response, request, result }
    end
  end

  def delete(url)
    if use_guisso?
      response = guisso_resource.delete(url)
      if response.ok?
        response.body
      else
        raise HttpError.new response
      end
    else
      rest_client_resource(url).delete { |response, request, result| handle_request response, request, result }
    end
  end

  def handle_request response, request, result
    result.error! if result.code_type.superclass == Net::HTTPClientError || result.code_type.superclass == Net::HTTPServerError
    response
  end

  def use_guisso?
    @connector.shared? and Guisso.enabled?
  end

  def guisso_resource
    Guisso.trusted_resource(@connector.url, @user.email)
  end

  def rest_client_resource(url)
    RestClient::Resource.new(url, @connector.username, @connector.password)
  end

  class HttpError < RuntimeError
    def initialize(response)
      @response = response
    end

    def message
      "HTTP status #{http_code}"
    end

    def http_code
      @response.status
    end

    def http_body
      @response.body
    end
  end
end
