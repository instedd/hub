Hercule::Backend.client = Elasticsearch::Client.new host: Settings.poirot.elasticsearch_url
