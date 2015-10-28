require 'machinist/active_record'

User.blueprint do
  email { "john+#{sn}@doe.com" }
  password { "foobarbaz" }
  confirmed_at { 2.days.ago }
end

Connector.blueprint do
  name { "Connector #{sn}" }
  user
end

ACTConnector.blueprint do
  name         { "Connector #{sn}" }
  url          { "http://example.com" }
  access_token { SecureRandom.hex(16).upcase }
end

ElasticsearchConnector.blueprint do
  name { "Connector #{sn}" }
  url { "http://localhost:9200" }
  user
end

ONAConnector.blueprint do
  name { "Connector #{sn}" }
  url { "http://example.com" }
  auth_method { "anonymous" }
end

MBuilderConnector.blueprint do
  name { "Connector #{sn}" }
end

VerboiceConnector.blueprint do
  name { "Connector #{sn}" }
  user
end

RapidProConnector.blueprint do
  name { "Connector #{sn}" }
  url { "https://rapidpro.io" }
  token { "token" }
end

CDXConnector.blueprint do
  name { "Connector #{sn}" }
  url { "https://cdx.com" }
  oauth_token { "foobarbaz" }
end

ResourceMapConnector.blueprint do
  name { "Connector #{sn}" }
  user
end

EventHandler.blueprint do
  connector
  event { 'info/$events/new_data'}
  action { 'info/$actions/call' }
end




