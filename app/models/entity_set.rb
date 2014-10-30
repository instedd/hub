module EntitySet
  def kind
    :entity_set
  end

  def lookup(path)
    return self if path.empty?
    entity_id = path.shift
    find_entity(entity_id).lookup(path)
  end

  def actions
  end

  def events
  end

  def reflect
    reflection = {}
    reflection[:entities] = entities.map do |entity|
      {name: entity.name, kind: entity.kind, path: entity.path}
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
