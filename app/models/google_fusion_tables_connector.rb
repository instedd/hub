class GoogleFusionTablesConnector < Connector
  include Entity

  store_accessor :settings, :access_token, :refresh_token, :expires_at

  validates_presence_of :access_token
  validates_presence_of :refresh_token
  validates_presence_of :expires_at

  def needs_authorization?
    true
  end

  def authorization_text
    "Save and authenticate with Google"
  end

  def authorization_uri(redirect_uri, state)
    client = api_client
    auth = client.authorization
    auth.redirect_uri = redirect_uri
    auth.state = state
    auth.authorization_uri(access_type: :offline, approval_prompt: :force).to_s
  end

  def callback_action
    :google_fusiontables_callback
  end

  def api_client
    self.class.api_client
  end

  def self.api_client
    client = Google::APIClient.new application_name: "InSTEDD Hub", application_version: "1.0"
    auth = client.authorization
    auth.client_id = Settings.google.client_id
    auth.client_secret = Settings.google.client_secret
    auth.scope = [
      "https://www.googleapis.com/auth/fusiontables",
      "https://www.googleapis.com/auth/userinfo.profile",
    ]
    client
  end


end
