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
  url { "http://example.com" }
end

ElasticsearchConnector.blueprint do
end

ONAConnector.blueprint do
  url { "http://example.com" }
  auth_method { "anonymous" }
end

VerboiceConnector.blueprint do
  user
end

