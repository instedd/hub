module EntitySet
  def lookup(path)
    return self if path.empty?
    entity_id = path.shift

    case entity_id
    when "$events"
      EventsNode.new(self).lookup(path)
    else
      find_entity(entity_id).lookup(path)
    end
  end

  def reflect_path
    path
  end

  def actions
  end

  def events
  end

  def reflect(reflect_url_proc)
    reflection = {}
    reflection[:entities] = entities.map do |entity|
      {label: entity.label, path: entity.path, reflect_url: reflect_url_proc.call(entity.path)}
    end
    if a = actions
      reflection[:actions] = a
    end
    if e = events
      reflection[:events] = e
    end
    reflection
  end
end
