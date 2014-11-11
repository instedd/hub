class GuissoRestClient
  def initialize(connector, user)
    @connector = connector
    @user = user
  end

  def get(url)
    JSON.parse(if use_guisso?
      guisso_resource.get(url).body
    else
      rest_client_resource(url).get()
    end)
  end

  def post(url, body="")
    if use_guisso?
      guisso_resource.post(url, body).body
    else
      rest_client_resource(url).post(body) {|response, request, result| response }
    end
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
end
