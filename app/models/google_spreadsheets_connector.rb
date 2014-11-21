class GoogleSpreadsheetsConnector < Connector
  include EntitySet

  store_accessor :settings, :access_token, :refresh_token, :expires_at, :spreadsheet_key, :spreadsheet_name

  validates_presence_of :access_token
  validates_presence_of :refresh_token
  validates_presence_of :expires_at

  def path
    ""
  end

  def entities(user)
    [Spreadsheet.new(self, spreadsheet_key, spreadsheet_name)]
  end

  def find_entity(key)
    Spreadsheet.new(self, key)
  end

  def needs_authorization?
    true
  end

  def authorization_text
    "Save and authenticate with Google"
  end

  def callback_action
    :google_spreadsheets_callback
  end

  def authorization_uri(redirect_uri, state)
    client = api_client
    auth = client.authorization
    auth.redirect_uri = redirect_uri
    auth.state = state
    auth.authorization_uri(access_type: :offline, approval_prompt: :force).to_s
  end

  def access_token
    if access_token_expired?
      token = OAuth2::AccessToken.from_hash(oauth_client, refresh_token: refresh_token)
      auth_token = token.refresh!
      self.access_token = auth_token.token
      self.expires_at = auth_token.expires_in.seconds.from_now
      self.refresh_token = auth_token.refresh_token if auth_token.refresh_token
      save!
    end
    settings[:access_token]
  end

  def access_token_expired?
    if expires_at
      Time.now > expires_at - 5.minutes
    else
      false
    end
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
      "https://www.googleapis.com/auth/drive.file",
      "https://www.googleapis.com/auth/drive.install",
      "https://www.googleapis.com/auth/userinfo.profile",
    ]
    client
  end

  def oauth_client
    self.class.oauth_client
  end

  def self.oauth_client
    OAuth2::Client.new(
        Settings.google.client_id,
        Settings.google.client_secret,
        site: "https://accounts.google.com",
        token_url: "/o/oauth2/token",
        authorize_url: "/o/oauth2/auth")
  end

  class Spreadsheet
    include Entity

    attr_reader :parent
    attr_reader :key

    def initialize(parent, key, name = nil)
      @parent = parent
      @key = key
      @name = name
    end

    def label
      @name
    end

    def path
      @key
    end

    def actions(user)
      {"insert_row" => InsertRow.new(self)}
    end
  end

  class InsertRow
    include Action

    attr_reader :parent

    def initialize(parent)
      @parent = parent
    end

    def label
      "Insert row"
    end

    def sub_path
      "insert_row"
    end

    def args(user)
      headers = worksheet.list.keys
      {
        properties: {
          type: {
            kind: :struct,
            members: Hash[headers.map { |h| [h, {type: :string}] }],
            open: true,
          },
        }
      }
    end

    def after_create(binding)
      define_columns_for binding
    end

    def after_update(binding)
      define_columns_for binding
    end

    def define_columns_for(binding)
      new_columns = binding["members"]["properties"]["open"].keys
      worksheet = self.worksheet
      list = worksheet.list
      headers = list.keys
      new_headers = (headers + new_columns).uniq
      list.keys = new_headers
      worksheet.save
    end

    def worksheet
      session = GoogleDrive.login_with_oauth(connector.access_token)
      spreadsheet = session.spreadsheet_by_key(parent.key)
      spreadsheet.worksheets.first
    end
  end
end
