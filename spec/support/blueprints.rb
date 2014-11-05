require 'machinist/active_record'

User.blueprint do
  email { "john+#{sn}@doe.com" }
  password { "foobarbaz" }
  confirmed_at { 2.days.ago }
end

Connector.blueprint do
  name { "Connector #{sn}" }
end
