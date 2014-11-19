class GoogleDriveConnector < Connector
  include Entity
  store_accessor :settings, :access_token, :refresh_token

  validates_presence_of :access_token
  validates_presence_of :refresh_token

  def needs_authorization?
    true
  end

  def authorization_text
    "Save and authenticate with Google"
  end

  def authorization_uri(redirect_uri)
    client = api_client
    auth = client.authorization
    auth.redirect_uri = redirect_uri
    auth.authorization_uri(access_type: :offline, approval_prompt: :force).to_s
  end

  def finish_authorization(params, redirect_uri)
    client = api_client
    auth = client.authorization
    auth.code = params[:code]
    auth.redirect_uri = redirect_uri
    access_token = auth.fetch_access_token!
    self.access_token = access_token["access_token"]
    self.refresh_token = access_token["refresh_token"]
  end

  def api_client
    self.class.api_client
  end

  def self.api_client
    client = Google::APIClient.new application_name: "InSTEDD Hub", application_version: "1.0"
    auth = client.authorization
    auth.client_id = Settings.google.client_id
    auth.client_secret = Settings.google.client_secret
    auth.scope =
      "https://www.googleapis.com/auth/drive.file " +
      "https://docs.google.com/feeds/ " +
      "https://docs.googleusercontent.com/ " +
      "https://spreadsheets.google.com/feeds/"
    client
  end
end
