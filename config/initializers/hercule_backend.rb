Hercule::Backend.client = Elasticsearch::Client.new(host: Settings.poirot.elasticsearch_url) unless Settings.poirot.elasticsearch_url.blank?
