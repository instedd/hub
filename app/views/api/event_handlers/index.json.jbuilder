json.event_handlers event_handlers do |event_handler|
  json.name event_handler.name
  json.enabled event_handler.enabled

  json.event do
    json.connector event_handler.connector.guid
    json.path event_handler.event
  end

  json.action do
    json.connector event_handler.target_connector.guid
    json.path event_handler.action
  end

  json.binding event_handler.binding
end
