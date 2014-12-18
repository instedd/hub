
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
end
