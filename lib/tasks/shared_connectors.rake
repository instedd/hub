
namespace :shared_connectors do

  task :create => :environment do
    is_stg = Guisso.url =~ /stg/
    app_suffix = is_stg ? ' (stg)' : ''
    url_suffix = is_stg ? '-stg' : ''

    VerboiceConnector.find_or_create_by name: "InSTEDD Verboice#{app_suffix}" do |c|
      c.url = "http://verboice#{url_suffix}.instedd.org"
      c.user =  nil
    end

    MBuilderConnector.find_or_create_by name: "InSTEDD mBuilder#{app_suffix}" do |c|
      c.url = "http://mbuilder#{url_suffix}.instedd.org"
      c.user = nil
    end

    ResourceMapConnector.find_or_create_by name: "InSTEDD Resource Map#{app_suffix}" do |c|
      if is_stg
        c.url = "http://resmap-stg.instedd.org"
      else
        c.url = "http://resourcemap.instedd.org"
      end
      c.user = nil
    end
  end

  desc "Registers (finds or creates) the info for a shared connector"
  task :register, [:name, :url, :type] => :environment do |task, args|
    klazz = args[:type].constantize
    connector = klazz.find_or_create_by(name: args[:name]) do |c|
      c.url = args[:url]
      c.user = nil
    end

    connector.generate_secret_token! if connector.secret_token.nil?

    puts "guid: #{connector.guid}\nsecret_token: #{connector.secret_token}"
  end

end
