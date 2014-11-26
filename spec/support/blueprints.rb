require 'machinist/active_record'

User.blueprint do
  email { "john+#{sn}@doe.com" }
  password { "foobarbaz" }
  confirmed_at { 2.days.ago }
end

Connector.blueprint do
  name { "Connector #{sn}" }
end

ACTConnector.blueprint do
  name { "Connector #{sn}" }
  url { "http://example.com" }
end

ElasticsearchConnector.blueprint do
  name { "Connector #{sn}" }
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

EventHandler.blueprint do
  connector
  event { 'info/$events/new_data'}
  action { 'info/$actions/call' }
end




