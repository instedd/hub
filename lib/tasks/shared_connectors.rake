
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
  end
end
